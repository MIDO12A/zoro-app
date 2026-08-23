/**
 * Scan Assets Script
 *
 * Walks the Flutter `assets/` directory, identifies meaningful asset files,
 * and outputs a seed SQL file (`supabase/migrations/20250615_seed_app_assets.sql`)
 * that can be run in Supabase to populate the `app_assets` table.
 *
 * Usage: node scripts/scan-assets.js
 *
 * The scanner:
 *  - Skips Android build infrastructure (layouts, values, anim, color-xml, etc.)
 *  - Focuses on: images (webp, png), SVGA, VAP, Lottie, sounds, gifs, fonts, etc.
 *  - Generates a deterministic `key` per file
 *  - Maps `type` from extension
 *  - Maps `category` from directory
 *  - Preserves manual names/categories from the existing hardcoded list in AppAssets.tsx
 */

const fs = require('fs');
const path = require('path');

const ASSETS_DIR = path.resolve(__dirname, '..', 'assets');
const OUTPUT_FILE = path.resolve(__dirname, '..', 'supabase', 'migrations', '20250615_seed_app_assets.sql');

// Directories to SKIP (Android build infrastructure, not real app assets)
const SKIP_DIRS = new Set([
  'layout', 'layout-land', 'layout-sw600dp', 'layout-v26', 'layout-watch',
  'values', 'values-h320dp-port', 'values-h360dp-land', 'values-h480dp-land',
  'values-h550dp-port', 'values-h720dp', 'values-land', 'values-large',
  'values-ldrtl', 'values-ldrtl-xxhdpi', 'values-mdpi', 'values-night',
  'values-nodpi', 'values-port', 'values-small', 'values-sw600dp',
  'values-v25', 'values-v26', 'values-v27', 'values-v28', 'values-v31',
  'values-w320dp-land', 'values-w360dp-port', 'values-w400dp-port',
  'values-w600dp-land', 'values-watch', 'values-xlarge', 'values-xxhdpi',
  'values-xxxhdpi',
  'anim', 'animator', 'interpolator', 'menu', 'xml',
  'color', 'color-night', 'color-v31',
  'drawable', 'drawable-ldrtl', 'drawable-ldrtl-xxhdpi',
  'drawable-mdpi', 'drawable-nodpi', 'drawable-watch',
  'drawable-xxxhdpi',
  'mipmap-anydpi-v26', 'mipmap-hdpi', 'mipmap-ldrtl-xxhdpi',
  'mipmap-mdpi', 'mipmap-xhdpi', 'mipmap-xxxhdpi',
  'dexopt', 'lang',
]);

// Directories that contain actual app assets
const CATEGORY_MAP = {
  'mipmap-xxhdpi': { category: 'ui', subcategory: 'icons' },
  'drawable-xxhdpi': { category: 'ui', subcategory: 'drawables' },
  'svga': { category: 'svga', subcategory: 'animations' },
  'vap': { category: 'vap', subcategory: 'animations' },
  'lottie': { category: 'lottie', subcategory: 'animations' },
  'vip': { category: 'vip', subcategory: 'cards' },
  'images': { category: 'vip', subcategory: 'cards' }, // images/vip/vipCard/
  'raw': { category: 'raw', subcategory: 'files' },
  'chatbuildinemojis': { category: 'emoji', subcategory: 'emojis' },
  'websvga': { category: 'svga', subcategory: 'web' },
  'websvgahead': { category: 'svga', subcategory: 'web-head' },
  'websvgaheadcircle': { category: 'svga', subcategory: 'web-head-circle' },
  'rank': { category: 'rank', subcategory: 'pages' },
};

const EXT_TYPE_MAP = {
  '.png': 'image',
  '.webp': 'image',
  '.jpg': 'image',
  '.jpeg': 'image',
  '.gif': 'gif',
  '.svga': 'svga',
  '.mp4': 'mp4',
  '.mp3': 'mp3',
  '.wav': 'wav',
  '.json': 'json',
  '.css': 'css',
  '.js': 'js',
  '.html': 'html',
  '.xml': 'xml',
  '.ttf': 'font',
  '.otf': 'font',
  '.woff': 'font',
  '.zip': 'other',
};

const MIME_MAP = {
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svga': 'application/octet-stream',
  '.mp4': 'video/mp4',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.json': 'application/json',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.html': 'text/html',
  '.xml': 'application/xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
};

function determineType(ext) {
  return EXT_TYPE_MAP[ext.toLowerCase()] || 'other';
}

function determineMime(ext) {
  return MIME_MAP[ext.toLowerCase()] || null;
}

function keyFromFilename(dir, filename) {
  const parsed = path.parse(filename);
  const base = parsed.name;

  // For .9.png files, strip the .9
  const clean = base.endsWith('.9') ? base.slice(0, -2) : base;

  // If in a subdirectory, add dir context
  const parts = dir.replace(/\\/g, '/').split('/');
  let prefix = '';
  for (const p of parts) {
    if (p === 'assets' || p === '..') continue;
    if (SKIP_DIRS.has(p)) continue;

    // Remove common duplicate prefixes
    const add = p.replace(/-xxhdpi$/i, '').replace(/-hdpi$/i, '');
    if (add && add !== '.') {
      // Only add if it adds uniqueness
      if (!clean.startsWith(add) && !clean.includes(add)) {
        prefix = add + '_';
      }
    }
  }

  // Handle images/vip/vipCard -> vip card prefix
  if (dir.includes('images') || dir.includes('vipCard')) {
    const match = clean.match(/^vip(\d+)$/i);
    if (match) {
      return `vip_card_${match[1]}`;
    }
  }

  return `${prefix}${clean}`.replace(/[^a-zA-Z0-9_]/g, '_').toLowerCase().replace(/__+/g, '_').replace(/^_|_$/g, '');
}

function scan() {
  const results = [];
  const existingKeys = new Set();

  function walk(currentDir, relPath) {
    let entries;
    try {
      entries = fs.readdirSync(currentDir, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      const fullPath = path.join(currentDir, entry.name);
      const entryRel = relPath ? `${relPath}/${entry.name}` : entry.name;

      if (entry.isDirectory()) {
        const dirName = entry.name;
        // Skip entire directory trees for excluded dirs
        if (SKIP_DIRS.has(dirName) && relPath === '') continue;
        walk(fullPath, entryRel);
      } else if (entry.isFile()) {
        const ext = path.extname(entry.name).toLowerCase();
        const type = determineType(ext);
        if (type === 'other' && ext !== '.zip' && ext !== '.9') continue;

        // Skip files that are clearly build artifacts
        if (entry.name.startsWith('._')) continue;

        // Determine category
        const parts = entryRel.split('/');
        let topDir = parts[0];
        let category, subcategory;

        if (CATEGORY_MAP[topDir]) {
          category = CATEGORY_MAP[topDir].category;
          subcategory = CATEGORY_MAP[topDir].subcategory;
          // For nested images/vip/vipCard
          if (topDir === 'images' && parts.includes('vipCard')) {
            category = 'vip';
            subcategory = 'vip-card';
          }
          if (topDir === 'rank') {
            if (parts.includes('common')) subcategory = 'common';
            else if (parts.includes('modules')) subcategory = 'modules';
          }
        } else {
          category = 'other';
          subcategory = topDir;
        }

        // Handle root-level files
        if (relPath === '') {
          if (ext === '.svga') {
            category = 'svga';
            subcategory = 'root';
          } else if (ext === '.html') {
            category = 'other';
            subcategory = 'root';
          } else {
            category = 'other';
            subcategory = 'root';
          }
        }

        const fileStat = fs.statSync(fullPath);
        const key = keyFromFilename(entryRel, entry.name);
        const id = `asset_${key}`;

        // Avoid duplicate keys
        if (existingKeys.has(key)) {
          const deduped = `${key}_${topDir}`;
          if (!existingKeys.has(deduped)) {
            existingKeys.add(deduped);
            results.push({
              id: `asset_${deduped}`,
              key: deduped,
              name: '',
              type,
              category,
              subcategory,
              localPath: entryRel,
              fileSize: fileStat.size,
              mimeType: determineMime(ext),
              sortOrder: 0,
            });
          }
          continue;
        }
        existingKeys.add(key);

        // For .9.png files, local path has the .9 in filename
        const localPath = entry.name.endsWith('.9.png')
          ? entryRel
          : entryRel;

        results.push({
          id,
          key,
          name: '',
          type,
          category,
          subcategory,
          localPath,
          fileSize: fileStat.size,
          mimeType: determineMime(ext),
          sortOrder: 0,
        });
      }
    }
  }

  walk(ASSETS_DIR, '');
  return results;
}

// Hardcoded manual names/categories from existing AppAssets.tsx
const MANUAL_ASSETS = {
  'mine_mall_top_bg_webp': { name: 'خلفية المتجر', category: 'store', subcategory: 'header' },
  'mine_mall_buy_ic_webp': { name: 'أيقونة الشراء', category: 'store', subcategory: 'icons' },
  'mine_mall_tab_vip_ic_webp': { name: 'أيقونة VIP', category: 'store', subcategory: 'icons' },
  'mine_vip_label_ic_webp': { name: 'ملصق VIP', category: 'store', subcategory: 'icons' },
  'mine_vip_go_webp': { name: 'سهم VIP', category: 'store', subcategory: 'icons' },
  'mine_vip_center_bg_webp': { name: 'خلفية VIP', category: 'store', subcategory: 'backgrounds' },
  'mine_wallet_header_bg_webp': { name: 'خلفية المحفظة', category: 'wallet', subcategory: 'header' },
  'mine_wallet_coin_bag_ic_webp': { name: 'كيس العملات', category: 'wallet', subcategory: 'coins' },
  'mine_wallet_detail_ic_webp': { name: 'تفاصيل المحفظة', category: 'wallet', subcategory: 'icons' },
  'mine_wallet_filter_ic_webp': { name: 'فلتر المحفظة', category: 'wallet', subcategory: 'icons' },
  'common_gold_ic_1_webp': { name: 'عملة ذهبية 1', category: 'wallet', subcategory: 'coins' },
  'common_gold_ic_2_webp': { name: 'عملة ذهبية 2', category: 'wallet', subcategory: 'coins' },
  'common_gold_ic_3_webp': { name: 'عملة ذهبية 3', category: 'wallet', subcategory: 'coins' },
  'common_gold_ic_4_webp': { name: 'عملة ذهبية 4', category: 'wallet', subcategory: 'coins' },
  'common_diamond_ic_webp': { name: 'ألماسة', category: 'wallet', subcategory: 'coins' },
  'level_top_bg_webp': { name: 'خلفية المستوى', category: 'level', subcategory: 'backgrounds' },
  'mine_level_ic_webp': { name: 'شارة المستوى', category: 'level', subcategory: 'badges' },
  'mine_union_ic_webp': { name: 'أيقونة النقابة', category: 'union', subcategory: 'icons' },
  'mine_top_bg_webp': { name: 'خلفية حسابي', category: 'account', subcategory: 'header' },
  'mine_btn_edit_ic_webp': { name: 'زر التعديل', category: 'account', subcategory: 'edit' },
  'mine_avatar_ic_webp': { name: 'إطار الصورة', category: 'account', subcategory: 'edit' },
  'mine_wallet_ic_webp': { name: 'أيقونة المحفظة', category: 'account', subcategory: 'menu' },
  'mine_backpack_ic_webp': { name: 'أيقونة الحقيبة', category: 'account', subcategory: 'menu' },
  'mine_mall_ic_webp': { name: 'أيقونة المتجر', category: 'account', subcategory: 'menu' },
  'mine_setting_ic_webp': { name: 'أيقونة الإعدادات', category: 'account', subcategory: 'menu' },
  'mine_feedback_ic_webp': { name: 'أيقونة الملاحظات', category: 'account', subcategory: 'menu' },
  'common_user_id_ic_webp': { name: 'أيقونة المعرف', category: 'account', subcategory: 'edit' },
  'common_id_copy_ic_webp': { name: 'نسخ المعرف', category: 'account', subcategory: 'edit' },
  'mine_google_ic_webp': { name: 'أيقونة جوجل', category: 'account', subcategory: 'settings' },
  'mine_facebook_ic_webp': { name: 'أيقونة فيسبوك', category: 'account', subcategory: 'settings' },
  'mine_phone_ic_webp': { name: 'أيقونة الهاتف', category: 'account', subcategory: 'settings' },
  'img_ask_webp': { name: 'أيقونة استفسار', category: 'account', subcategory: 'settings' },
  'discover_header_bg_webp': { name: 'خلفية الاكتشاف', category: 'discover', subcategory: 'header' },
  'discover_search_ic_webp': { name: 'أيقونة البحث', category: 'discover', subcategory: 'header' },
  'discover_room_ic_webp': { name: 'أيقونة الغرفة', category: 'discover', subcategory: 'header' },
  'discover_music_ic_webp': { name: 'أيقونة الموسيقى', category: 'discover', subcategory: 'categories' },
  'discover_room_social_share_ic_webp': { name: 'مشاركة اجتماعية', category: 'discover', subcategory: 'categories' },
  'discover_item_chat_bg_webp': { name: 'خلفية دردشة', category: 'discover', subcategory: 'room-cards' },
  'discover_item_music_bg_webp': { name: 'خلفية موسيقى', category: 'discover', subcategory: 'room-cards' },
  'discover_item_game_bg_webp': { name: 'خلفية ألعاب', category: 'discover', subcategory: 'room-cards' },
  'discover_item_hobby_bg_webp': { name: 'خلفية هوايات', category: 'discover', subcategory: 'room-cards' },
  'discover_item_party_bg_webp': { name: 'خلفية حفلات', category: 'discover', subcategory: 'room-cards' },
  'discover_item_friend_bg_webp': { name: 'خلفية أصدقاء', category: 'discover', subcategory: 'room-cards' },
  'discover_room_chat_ic_webp': { name: 'أيقونة الدردشة', category: 'discover', subcategory: 'categories' },
  'discover_room_enjoy_music_webp': { name: 'أيقونة الموسيقى', category: 'discover', subcategory: 'categories' },
  'discover_room_game_team_ic_webp': { name: 'أيقونة الألعاب', category: 'discover', subcategory: 'categories' },
  'discover_room_hobby_ic_webp': { name: 'أيقونة الهوايات', category: 'discover', subcategory: 'categories' },
  'discover_room_party_ic_webp': { name: 'أيقونة الحفلات', category: 'discover', subcategory: 'categories' },
  'discover_game_teaming_ic_webp': { name: 'أيقونة الفرق', category: 'discover', subcategory: 'categories' },
  'room_hot_logo_ic_webp': { name: 'علامة النشاط', category: 'discover', subcategory: 'room-cards' },
  'room_create_room_bg_webp': { name: 'خلفية إنشاء غرفة', category: 'discover', subcategory: 'room-cards' },
  'room_create_label_ic_webp': { name: 'ملصق إنشاء غرفة', category: 'discover', subcategory: 'room-cards' },
  'room_create_hobby_refresh_ic_webp': { name: 'تحديث الهوايات', category: 'discover', subcategory: 'room-cards' },
  'common_camera_ic_webp': { name: 'أيقونة الكاميرا', category: 'discover', subcategory: 'room-cards' },
  'room_bg_friend_webp': { name: 'خلفية الغرفة', category: 'room', subcategory: 'backgrounds' },
  'room_bg_seat_pre_webp': { name: 'خلفية المقعد', category: 'room', subcategory: 'backgrounds' },
  'room_micphone_ic_webp': { name: 'أيقونة المايك', category: 'room', subcategory: 'mic' },
  'room_micphone_close_ic_webp': { name: 'مايك مغلق', category: 'room', subcategory: 'mic' },
  'room_mic_on_webp': { name: 'مايك تشغيل', category: 'room', subcategory: 'mic' },
  'room_mic_off_webp': { name: 'مايك إيقاف', category: 'room', subcategory: 'mic' },
  'room_mic_down_webp': { name: 'مايك خفض', category: 'room', subcategory: 'mic' },
  'room_gift_ic_webp': { name: 'زر الهدية', category: 'room', subcategory: 'gift-panel' },
  'room_gift_panel_select_owner_ic_webp': { name: 'اختيار مالك الهدية', category: 'room', subcategory: 'gift-panel' },
  'room_set_music_ic_webp': { name: 'إعدادات الموسيقى', category: 'room', subcategory: 'controls' },
  'room_emoj_ic_webp': { name: 'زر الإيموجي', category: 'room', subcategory: 'controls' },
  'room_chat_ic_webp': { name: 'زر الدردشة', category: 'room', subcategory: 'controls' },
  'room_exit_ic_webp': { name: 'زر الخروج', category: 'room', subcategory: 'controls' },
  'room_game_ic_webp': { name: 'زر اللعبة', category: 'room', subcategory: 'controls' },
  'room_lock_state_ic_webp': { name: 'أيقونة القفل', category: 'room', subcategory: 'controls' },
  'room_seat_normal_bg_webp': { name: 'مقعد عادي', category: 'room', subcategory: 'seats' },
  'room_seat_vip_bg_webp': { name: 'مقعد VIP', category: 'room', subcategory: 'seats' },
  'room_seat_host_bg_webp': { name: 'مقعد المضيف', category: 'room', subcategory: 'seats' },
  'room_seat_mic_bg_webp': { name: 'مقعد المايك', category: 'room', subcategory: 'seats' },
  'room_seat_empty_bg_webp': { name: 'مقعد فارغ', category: 'room', subcategory: 'seats' },
  'room_seat_occupied_bg_webp': { name: 'مقعد مشغول', category: 'room', subcategory: 'seats' },
  'room_seat_lock_ic_webp': { name: 'قفل المقعد', category: 'room', subcategory: 'seats' },
  'chat_message_system_bg_webp': { name: 'خلفية نظام الدردشة', category: 'chat', subcategory: 'backgrounds' },
  'chat_message_information_bg_webp': { name: 'خلفية معلومات الدردشة', category: 'chat', subcategory: 'backgrounds' },
  'bg_login_webp': { name: 'خلفية تسجيل الدخول', category: 'login', subcategory: 'backgrounds' },
  'login_welcome_ic_webp': { name: 'شعار الترحيب', category: 'login', subcategory: 'backgrounds' },
  'login_google_ic_webp': { name: 'زر جوجل', category: 'login', subcategory: 'buttons' },
  'login_fb_ic_webp': { name: 'زر فيسبوك', category: 'login', subcategory: 'buttons' },
  'login_phone_ic_webp': { name: 'زر الهاتف', category: 'login', subcategory: 'buttons' },
  'ic_launcher_webp': { name: 'أيقونة التطبيق', category: 'login', subcategory: 'backgrounds' },
  'splash_img_logo_webp': { name: 'شعار البداية', category: 'login', subcategory: 'backgrounds' },
  'tab_discover_nor_webp': { name: 'اكتشف - عادي', category: 'nav', subcategory: 'tabs' },
  'tab_discover_pre_webp': { name: 'اكتشف - محدد', category: 'nav', subcategory: 'tabs' },
  'tab_message_nor_webp': { name: 'الرسائل - عادي', category: 'nav', subcategory: 'tabs' },
  'tab_message_pre_webp': { name: 'الرسائل - محدد', category: 'nav', subcategory: 'tabs' },
  'tab_mine_nor_webp': { name: 'حسابي - عادي', category: 'nav', subcategory: 'tabs' },
  'tab_mine_pre_webp': { name: 'حسابي - محدد', category: 'nav', subcategory: 'tabs' },
  'ava_boy_webp': { name: 'صورة ولد', category: 'common', subcategory: 'avatars' },
  'ava_girl_webp': { name: 'صورة بنت', category: 'common', subcategory: 'avatars' },
  'ic_sex_boy_webp': { name: 'ذكر', category: 'common', subcategory: 'gender' },
  'ic_sex_girl_webp': { name: 'أنثى', category: 'common', subcategory: 'gender' },
  'sex_male_ic_webp': { name: 'ذكر (2)', category: 'common', subcategory: 'gender' },
  'sex_female_ic_webp': { name: 'أنثى (2)', category: 'common', subcategory: 'gender' },
  'back_ic_webp': { name: 'رجوع', category: 'common', subcategory: 'arrows' },
  'back_white_webp': { name: 'رجوع أبيض', category: 'common', subcategory: 'arrows' },
  'back_white_2_webp': { name: 'رجوع أبيض 2', category: 'common', subcategory: 'arrows' },
  'next_black_ic_webp': { name: 'سهم أسود', category: 'common', subcategory: 'arrows' },
  'common_next_4_ic_webp': { name: 'سهم 4', category: 'common', subcategory: 'arrows' },
  'common_back_2_webp': { name: 'رجوع 2', category: 'common', subcategory: 'arrows' },
  'common_close_ic_webp': { name: 'إغلاق', category: 'common', subcategory: 'icons' },
  'common_empty_ic_1_webp': { name: 'فارغ', category: 'common', subcategory: 'icons' },
  'mine_photo_add_ic_webp': { name: 'إضافة صورة', category: 'common', subcategory: 'icons' },
  'mine_camera_ic_webp': { name: 'كاميرا', category: 'common', subcategory: 'icons' },
  'rank_wealth_bg_webp': { name: 'خلفية الترتيب', category: 'common', subcategory: 'icons' },
  'rank_tab_item_bg_webp': { name: 'خلفية تبويب الترتيب', category: 'common', subcategory: 'icons' },
  'super_admin_frame_svga': { name: 'إطار المشرف', category: 'svga', subcategory: 'frames' },
  'super_admin_svga': { name: 'مشرف', category: 'svga', subcategory: 'frames' },
  'gift_anim_svga': { name: 'أنيميشن الهدية', category: 'svga', subcategory: 'animations' },
  'gift_svga': { name: 'هدية', category: 'svga', subcategory: 'animations' },
  'miao_svga': { name: 'مياو', category: 'svga', subcategory: 'animations' },
  'room_fm_wave_male_svga': { name: 'موجة FM ذكر', category: 'svga', subcategory: 'waves' },
  'room_fm_wave_female_svga': { name: 'موجة FM أنثى', category: 'svga', subcategory: 'waves' },
  'room_speaking_wave_male_svga': { name: 'موجة تكلم ذكر', category: 'svga', subcategory: 'waves' },
  'room_speaking_wave_female_svga': { name: 'موجة تكلم أنثى', category: 'svga', subcategory: 'waves' },
};

function escapeSql(val) {
  if (val === null || val === undefined) return 'NULL';
  return `'${String(val).replace(/'/g, "''")}'`;
}

function generateSeedSQL(assets) {
  const lines = [
    '-- ============================================================',
    '-- Seed: Populate app_assets table from auto-scan',
    '-- Generated by scripts/scan-assets.js',
    '-- ============================================================',
    '',
    '-- Apply manual names/categories from existing AppAssets.tsx list',
    'UPDATE app_assets SET',
    '  name = CASE key',
  ];

  // Add name CASE statements
  for (const [key, manual] of Object.entries(MANUAL_ASSETS)) {
    lines.push(`    WHEN ${escapeSql(key)} THEN ${escapeSql(manual.name)}`);
  }
  lines.push('    ELSE name');
  lines.push('  END,');

  // Add category CASE
  lines.push('  category = CASE key');
  for (const [key, manual] of Object.entries(MANUAL_ASSETS)) {
    lines.push(`    WHEN ${escapeSql(key)} THEN ${escapeSql(manual.category)}`);
  }
  lines.push('    ELSE category');
  lines.push('  END,');

  // Add subcategory CASE
  lines.push('  subcategory = CASE key');
  for (const [key, manual] of Object.entries(MANUAL_ASSETS)) {
    lines.push(`    WHEN ${escapeSql(key)} THEN ${escapeSql(manual.subcategory)}`);
  }
  lines.push('    ELSE subcategory');
  lines.push('  END');
  lines.push('WHERE key IN (' + Object.keys(MANUAL_ASSETS).map(k => escapeSql(k)).join(', ') + ');');
  lines.push('');

  return lines.join('\n');
}

// Main
console.log('🔍 Scanning assets directory...');
const scanned = scan();
console.log(`📦 Found ${scanned.length} assets.`);

// Write seed SQL
const sql = `-- ============================================================
-- Seed: Populate app_assets table from auto-scan
-- Generated by scripts/scan-assets.js
-- Run AFTER supabase/migrations/20250615_app_assets.sql
-- ============================================================

-- Insert all discovered assets
INSERT INTO app_assets (id, key, name, type, category, subcategory, local_path, mime_type, file_size, sort_order)
VALUES
${scanned.map(a => `  (${escapeSql(a.id)}, ${escapeSql(a.key)}, ${escapeSql(a.name)}, ${escapeSql(a.type)}, ${escapeSql(a.category)}, ${escapeSql(a.subcategory)}, ${escapeSql(a.localPath)}, ${escapeSql(a.mimeType)}, ${a.fileSize}, ${a.sortOrder})`).join(',\n')}
ON CONFLICT (id) DO UPDATE SET
  key = EXCLUDED.key,
  type = EXCLUDED.type,
  category = EXCLUDED.category,
  subcategory = EXCLUDED.subcategory,
  local_path = EXCLUDED.local_path,
  mime_type = EXCLUDED.mime_type,
  file_size = EXCLUDED.file_size,
  updated_at = NOW();

-- Apply manual names/categories from existing AppAssets.tsx
UPDATE app_assets SET
  name = CASE key
${Object.entries(MANUAL_ASSETS).map(([k, v]) => `    WHEN ${escapeSql(k)} THEN ${escapeSql(v.name)}`).join('\n')}
    ELSE name
  END,
  category = CASE key
${Object.entries(MANUAL_ASSETS).map(([k, v]) => `    WHEN ${escapeSql(k)} THEN ${escapeSql(v.category)}`).join('\n')}
    ELSE category
  END,
  subcategory = CASE key
${Object.entries(MANUAL_ASSETS).map(([k, v]) => `    WHEN ${escapeSql(k)} THEN ${escapeSql(v.subcategory)}`).join('\n')}
    ELSE subcategory
  END,
  updated_at = NOW()
WHERE key IN (${Object.keys(MANUAL_ASSETS).map(k => escapeSql(k)).join(', ')});

-- Generate names for unnamed assets (use key as fallback)
UPDATE app_assets SET name = key WHERE name = '' OR name IS NULL;

-- Mark assets in skipped categories or with non-image types as inactive
-- (these are build-support files, not customizable app assets)
UPDATE app_assets SET is_active = false WHERE category IN ('other', 'rank');

SELECT COUNT(*) AS total_assets FROM app_assets;
SELECT COUNT(*) AS active_assets FROM app_assets WHERE is_active = true;
`;

fs.writeFileSync(OUTPUT_FILE, sql, 'utf8');
console.log(`✅ Seed SQL written to ${OUTPUT_FILE}`);
console.log(`   ${scanned.length} assets written.`);
console.log(`   ${Object.keys(MANUAL_ASSETS).length} have manual names.`);
