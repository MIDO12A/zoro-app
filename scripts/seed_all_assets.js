const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = 'D:\\500\\New Folder\\alpha\\New folder\\zero';
const ASSETS_DIR = path.join(ROOT, 'assets');
const OUTPUT = path.join(ROOT, 'tmp', 'seed_all_assets.sql');

// Files/dirs to exclude (Android libs, build infra)
const EXCLUDE_DIRS = new Set([
  'anim', 'animator', 'color', 'color-night', 'color-v31', 'mipmap-anydpi-v26',
  'interpolator', 'layout', 'layout-land', 'layout-sw600dp', 'layout-v26', 'layout-watch',
  'menu', 'values', 'values-land', 'values-port', 'values-night',
  'values-h320dp-port', 'values-h360dp-land', 'values-h480dp-land', 'values-h550dp-port',
  'values-h720dp', 'values-large', 'values-ldrtl', 'values-ldrtl-xxhdpi', 'values-mdpi',
  'values-nodpi', 'values-small', 'values-sw600dp', 'values-v25', 'values-v26', 'values-v27',
  'values-v28', 'values-v31', 'values-w320dp-land', 'values-w360dp-port', 'values-w400dp-port',
  'values-w600dp-land', 'values-watch', 'values-xlarge', 'values-xxhdpi', 'values-xxxhdpi',
  'dexopt', 'lang', 'xml',
  'drawable-mdpi', 'drawable-nodpi', 'drawable-watch',
  'drawable-ldrtl', 'drawable-ldrtl-xxhdpi', 'drawable-xxxhdpi',
  'mipmap-hdpi', 'mipmap-mdpi', 'mipmap-xhdpi', 'mipmap-xxxhdpi',
  'mipmap-ldrtl-xxhdpi',
  'websvga', 'websvgahead', 'websvgaheadcircle',
]);

  // Files with these extensions are excluded
const EXCLUDE_EXT = new Set(['.keep', '.binarypb', '.html', '.css']);

// Files matching these patterns are excluded
const EXCLUDE_PATTERNS = [/firebase_/, /heterodyne/, /registration_info/];

// For drawable XML files, only include app-specific ones
const APP_XML_PREFIXES = [
  'room_', 'chat_', 'mine_', 'discover_', 'union_', 'rank_', 'wallet_', 'music_',
  'login_', 'shape', 'bg_', 'indicator_', 'selector_', 'layer_', 'splash_',
  'btn_', 'button_', 'checkbox_', 'switch_', 'seekbar_', 'tab_', 'me_', 'msg_',
  'voice_', 'play_', 'recording_', 'popu_', 'popup_', 'language_', 'gray_',
  'white_', 'selected_', 'message_', 'quote_', 'group_', 'core_', 'conversation_',
  'face_', 'ps_', 'qmui_', 'action_', 'recording_', 'thumb_', 'view_', 'web_',
  'minimalist_', 'live_', 'pay_', 'test_', 'tooltip_',
];

// Type mapping
function getType(ext) {
  const map = {
    'webp': 'image', 'png': 'image', 'jpg': 'image', 'jpeg': 'image', 'gif': 'image',
    'svga': 'svga', 'vap': 'vap', 'mp4': 'mp4', 'mp3': 'mp3', 'wav': 'wav',
    'json': 'json', 'xml': 'xml',
  };
  return map[ext] || 'other';
}

function getMime(ext) {
  const map = {
    'webp': 'image/webp', 'png': 'image/png', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
    'gif': 'image/gif', 'svga': 'application/octet-stream', 'vap': 'video/mp4',
    'mp4': 'video/mp4', 'mp3': 'audio/mpeg', 'wav': 'audio/wav',
    'json': 'application/json', 'xml': 'text/xml',
  };
  return map[ext] || 'application/octet-stream';
}

function categoryFromPath(relPath) {
  const p = relPath.replace(/\\/g, '/').toLowerCase();
  const base = path.basename(relPath).toLowerCase().replace(/\.[^.]+$/, '');
  const dir = path.dirname(relPath).replace(/\\/g, '/').toLowerCase();

  // SVGA
  if (p.endsWith('.svga')) return 'SVGA';
  // Lottie
  if (p.includes('lottie/')) return 'Lottie';
  // VAP
  if (p.includes('vap/')) return 'VAP';
  // Raw audio
  if (p.includes('raw/')) return 'الصوتيات';
  // Chat emojis
  if (p.includes('chatbuildinemojis')) return 'الإيموجي';
  // VIP card
  if (p.includes('images/vip/vipcard') || p.includes('images\\vip\\vipcard')) return 'بطاقات VIP';
  // VIP directory (images/vip/)
  if (p.includes('/vip/') || p.includes('\\vip\\')) {
    if (p.includes('images/vip/') || p.includes('images\\vip\\')) {
      return 'بطاقات VIP';
    }
    return 'العضويات';
  }

  // VIP dir at root
  if (p.startsWith('vip/') || p.startsWith('vip\\')) return 'العضويات';

  // Drawable XML - categorize by prefix
  if (p.includes('/drawable/') || p.includes('\\drawable\\')) {
    if (base.startsWith('room_')) return 'الغرفة';
    if (base.startsWith('chat_')) return 'الشات';
    if (base.startsWith('mine_')) return 'حسابي';
    if (base.startsWith('discover_')) return 'الاستكشاف';
    if (base.startsWith('union_')) return 'النقابات';
    if (base.startsWith('rank_')) return 'الترتيب';
    if (base.startsWith('wallet_')) return 'المحفظة';
    if (base.startsWith('music_')) return 'الموسيقى';
    if (base.startsWith('login_') || base.startsWith('splash_')) return 'تسجيل الدخول';
    if (base.startsWith('core_') || base.startsWith('conversation_')) return 'عام';
    if (base.startsWith('ps_') || base.startsWith('ucrop_')) return 'الصور';
    if (base.startsWith('qmui_')) return 'القوائم';
    return 'أشكال XML';
  }

  // Drawable-xxhdpi
  if (p.includes('drawable-xxhdpi') || p.includes('drawable_xxhdpi')) {
    if (base.startsWith('chat_') || base.startsWith('conversation_')) return 'الشات';
    if (base.startsWith('pop_menu') || base.startsWith('qmui_')) return 'القوائم';
    if (base.startsWith('live_')) return 'عام';
    if (base.startsWith('ps_')) return 'الصور';
    if (base.startsWith('multi_select')) return 'عام';
    if (base.startsWith('core_')) return 'عام';
    if (base.startsWith('ic_volume') || base.startsWith('ic_more_') || base.startsWith('ic_')) return 'عام';
    if (base.startsWith('check_') || base.startsWith('emoji_') || base.startsWith('face_')) return 'عام';
    if (base.startsWith('file_') || base.startsWith('group_')) return 'عام';
    if (base.startsWith('create_') || base.startsWith('custom') || base.startsWith('reply_')) return 'عام';
    if (base.startsWith('title_')) return 'عام';
    if (base.startsWith('room_')) return 'الغرفة';
    return 'عام';
  }

  // Mipmap-xxhdpi: categorize by prefix
  if (p.includes('mipmap-xxhdpi') || p.includes('mipmap_xxhdpi')) {
    if (base.startsWith('room_')) {
      if (base.startsWith('room_vip_') || base.includes('_vip_')) return 'العضويات';
      return 'الغرفة';
    }
    if (base.startsWith('discover_')) return 'الاستكشاف';
    if (base.startsWith('mine_')) {
      if (base.includes('wallet')) return 'المحفظة';
      if (base.includes('mall') || base.includes('shop')) return 'المتجر';
      if (base.includes('vip')) return 'العضويات';
      if (base.includes('level')) return 'المستوى';
      if (base.includes('set') || base.includes('setting')) return 'الإعدادات';
      return 'حسابي';
    }
    if (base.startsWith('tab_discover') || base.startsWith('tab_follow') || base.startsWith('tab_recent')) return 'الاستكشاف';
    if (base.startsWith('tab_message')) return 'الرسايل';
    if (base.startsWith('tab_mine')) return 'حسابي';
    if (base.startsWith('tab_')) return 'عام';
    if (base.startsWith('rank_')) return 'الترتيب';
    if (base.startsWith('union_') || base.startsWith('unions_')) return 'النقابات';
    if (base.startsWith('music_')) return 'الموسيقى';
    if (base.startsWith('wallet_')) return 'المحفظة';
    if (base.startsWith('login_') || base.startsWith('bg_login') || base.startsWith('splash_')) return 'تسجيل الدخول';
    if (base.startsWith('chat_')) return 'الشات';
    if (base.startsWith('level_')) return 'المستوى';
    if (base.startsWith('home_')) return 'الصفحة الرئيسية';
    if (base.startsWith('sex_') || base.startsWith('ic_sex_') || base.startsWith('ava_') || base.startsWith('ic_boy') || base.startsWith('ic_girl')) return 'عام';
    if (base.startsWith('ic_launcher')) return 'عام';
    if (base.startsWith('back_') || base.startsWith('next_') || base.startsWith('common_') || base.startsWith('commonui_')) return 'عام';
    if (base.startsWith('gift_')) return 'الغرفة';
    if (base.startsWith('ic_') || base.startsWith('img_')) return 'عام';
    if (base.startsWith('placeholder_')) return 'عام';
    return 'عام';
  }

  return 'أخرى';
}

function subcategoryFromPath(relPath) {
  const p = relPath.replace(/\\/g, '/').toLowerCase();
  const base = path.basename(relPath).toLowerCase().replace(/\.[^.]+$/, '');
  const dir = path.dirname(relPath).replace(/\\/g, '/').toLowerCase();

  if (p.endsWith('.svga')) return 'رسوم متحركة';
  if (p.includes('lottie/')) return 'رسوم متحركة';
  if (p.includes('vap/')) return 'فيديو';
  if (p.includes('raw/')) return 'مؤثرات';
  if (p.includes('chatbuildinemojis')) return 'رموز تعبيرية';
  if (p.includes('images/vip/vipcard') || p.includes('images\\vip\\vipcard')) return 'بطاقات';
  if (p.includes('/drawable/') || p.includes('\\drawable\\')) return 'أشكال';
  if (p.includes('drawable-xxhdpi') || p.includes('drawable_xxhdpi')) {
    if (base.startsWith('chat_bubble')) return 'فقاعات الشات';
    if (base.startsWith('chat_input') || base.startsWith('chat_voice') || base.startsWith('chat_function')) return 'واجهة الشات';
    if (base.startsWith('chat_title')) return 'شريط الشات';
    if (base.startsWith('chat_permission')) return 'أذونات الشات';
    if (base.startsWith('chat_send')) return 'إرسال';
    if (base.startsWith('chat_right')) return 'يمين الشات';
    if (base.startsWith('chat_camera')) return 'كاميرا الشات';
    if (base.startsWith('pop_menu')) return 'قوائم منبثقة';
    if (base.startsWith('core_')) return 'الأساسيات';
    if (base.startsWith('ps_')) return 'منتقي الصور';
    if (base.startsWith('conversation')) return 'المحادثات';
    if (base.startsWith('ic_volume')) return 'التحكم بالصوت';
    if (base.startsWith('ic_more_')) return 'المزيد';
    if (base.startsWith('multi_select')) return 'تحديد متعدد';
    return 'عام';
  }
  if (p.includes('mipmap-xxhdpi') || p.includes('mipmap_xxhdpi')) {
    if (base.startsWith('room_gift')) return 'الهدايا';
    if (base.startsWith('room_mic') || base.startsWith('room_micphone')) return 'الميكروفون';
    if (base.startsWith('room_bg') || base.startsWith('room_set_') || base.startsWith('room_seat_')) return 'الكراسي';
    if (base.startsWith('room_user_') && (base.includes('follow') || base.includes('info') || base.includes('chat'))) return 'المستخدمين';
    if (base.startsWith('room_vip_')) return 'VIP';
    if (base.startsWith('room_game_') || base.startsWith('room_chat_')) return 'الألعاب';
    if (base.startsWith('room_dialog_')) return 'الحوارات';
    if (base.startsWith('room_emoj') || base.startsWith('room_lucky_')) return 'التفاعل';
    if (base.startsWith('room_create_')) return 'إنشاء الغرفة';
    if (base.startsWith('room_')) return 'عام';
    if (base.startsWith('discover_room_') || base.startsWith('discover_header_') || base.startsWith('discover_tab_') || base.startsWith('discover_item_') || base.startsWith('discover_search_') || base.startsWith('discover_country_') || base.startsWith('discover_music_')) return 'عام';
    if (base.startsWith('mine_mall_')) return 'المتجر';
    if (base.startsWith('mine_wallet_')) return 'المحفظة';
    if (base.startsWith('mine_set_') || base.startsWith('mine_setting')) return 'الإعدادات';
    if (base.startsWith('mine_vip_')) return 'العضويات';
    if (base.startsWith('mine_')) return 'عام';
    if (base.startsWith('tab_')) return 'الأشرطة';
    if (base.startsWith('rank_')) return 'عام';
    if (base.startsWith('union_') || base.startsWith('unions_')) return 'عام';
    if (base.startsWith('music_')) return 'عام';
    if (base.startsWith('wallet_')) return 'عام';
    if (base.startsWith('login_') || base.startsWith('splash_')) return 'عام';
    if (base.startsWith('level_')) return 'الخلفيات';
    if (base.startsWith('chat_')) return 'عام';
    if (base.startsWith('home_')) return 'عام';
    if (base.startsWith('common_') || base.startsWith('commonui_')) return 'عام';
    return 'عام';
  }
  if (p.startsWith('vip/') || p.startsWith('vip\\')) {
    if (base.startsWith('ico_vip_lv') || base.startsWith('vip') && base.match(/^vip\d/)) return 'مستويات';
    if (base.startsWith('ico_vip_marking')) return 'شارات';
    if (base.startsWith('ico_emoji') || base.startsWith('ico_recording')) return 'مميزات';
    if (base.startsWith('ico_vip_0')) return 'قدرات';
    if (base.startsWith('dressing_')) return 'ملابس';
    if (base.startsWith('icon_vip_stealth')) return 'اختفاء';
    if (base.startsWith('img_vip') || base.startsWith('bg_vip') || base.startsWith('img_frame') || base.startsWith('img_kuang') || base.startsWith('img_popup') || base.startsWith('vip_line')) return 'صور';
    if (base.startsWith('icon_my_vip') || base.startsWith('icon_me')) return 'أيقونات';
    if (base.startsWith('btn_')) return 'أزرار';
    if (base.startsWith('vip_power')) return 'قدرات';
    if (base.startsWith('avatar')) return 'الصورة الشخصية';
    return 'عام';
  }
  return '';
}

function generateName(filePath) {
  const base = path.basename(filePath).replace(/\.[^.]+$/, '');
  return base.replace(/[_\.-]/g, ' ').replace(/\s+/g, ' ').trim();
}

// Collect all assets
const assets = [];
const seenKeys = new Set();

function addAsset(filePath) {
  const relPath = path.relative(ROOT, filePath).replace(/\\/g, '/');
  if (EXCLUDE_DIRS.has(path.dirname(relPath).split('/')[1])) return;
  
  const ext = path.extname(filePath).slice(1).toLowerCase();
  if (!ext || EXCLUDE_EXT.has('.' + ext)) return;
  
  // Skip firebase and other junk
  const baseName = path.basename(filePath).toLowerCase();
  if (EXCLUDE_PATTERNS.some(p => p.test(baseName))) return;
  
  // Skip Android library XML
  if (ext === 'xml') {
    const base = path.basename(filePath).toLowerCase();
    if (base.startsWith('abc_') || base.startsWith('mtrl_') || base.startsWith('_mtrl_') ||
        base.startsWith('m3_') || base.startsWith('_m3_') || base.startsWith('_avd_') ||
        base.startsWith('avd_') || base.startsWith('design_') || base.startsWith('notification_') ||
        base.startsWith('com_') || base.startsWith('common_google_') || base.startsWith('pay_button_') ||
        base.startsWith('button_dialogx_') || base.startsWith('rect_dialogx_') ||
        base.startsWith('tuiemoji_') || base.startsWith('material_') || base.startsWith('ucrop_') ||
        base.startsWith('navigation_') || base.startsWith('messenger_') ||
        base.startsWith('tooltip_') || base.startsWith('web_progress_'))
      return;
  }
  
  // Skip web SVGA infrastructure
  if (relPath.startsWith('websvga/') || relPath.startsWith('websvgahead/') || relPath.startsWith('websvgaheadcircle/')) {
    if (ext === 'js' || ext === 'html') return;
  }
  
  // Skip RTL
  if (relPath.includes('mipmap-ldrtl') || relPath.includes('drawable-ldrtl')) return;
  
  const type = getType(ext);
  const category = categoryFromPath(relPath);
  const subcategory = subcategoryFromPath(relPath);
  const name = generateName(filePath);
  const mime = getMime(ext);
  
  let size = 0;
  try { size = fs.statSync(filePath).size; } catch(e) {}
  
  // Generate stable key
  const key = relPath.replace(/[\/\.]/g, '_').replace(/[^a-zA-Z0-9_]/g, '_');
  if (seenKeys.has(key)) return;
  seenKeys.add(key);
  
  const catOrder = {
    'الغرفة': 1, 'الاستكشاف': 2, 'الرسايل': 3, 'حسابي': 4, 'الشات': 5,
    'العضويات': 6, 'بطاقات VIP': 7, 'SVGA': 8, 'Lottie': 9, 'VAP': 10,
    'الترتيب': 11, 'النقابات': 12, 'المتجر': 13, 'المحفظة': 14,
    'الموسيقى': 15, 'تسجيل الدخول': 16, 'الإعدادات': 17, 'المستوى': 18,
    'الإيموجي': 19, 'الصوتيات': 20, 'الصور': 21, 'القوائم': 22,
    'الصفحة الرئيسية': 23, 'عام': 24, 'أشكال XML': 25, 'XML': 26, 'أخرى': 27,
  };
  const sortOrder = (catOrder[category] || 99) * 10000;
  
  assets.push({ key, name, type, category, subcategory, localPath: relPath, mime, size, sortOrder });
}

// Walk through all relevant directories
const dirsToWalk = [
  'assets/mipmap-xxhdpi',
  'assets/svga',
  'assets/lottie',
  'assets/vap',
  'assets/vip',
  'assets/images/vip/vipCard',
  'assets/drawable-xxhdpi',
  'assets/chatbuildinemojis',
  'assets/raw',
  'assets/drawable',
];

for (const dir of dirsToWalk) {
  const fullPath = path.join(ROOT, dir);
  if (!fs.existsSync(fullPath)) continue;
  
  const entries = fs.readdirSync(fullPath, { withFileTypes: true, recursive: true });
  for (const entry of entries) {
    if (entry.isFile()) {
      addAsset(path.join(fullPath, entry.name));
    }
  }
}

// Add root SVGA files
const rootSvga = ['assets/room_speaking_wave_female.svga', 'assets/room_speaking_wave_male.svga'];
for (const f of rootSvga) {
  if (fs.existsSync(path.join(ROOT, f))) addAsset(path.join(ROOT, f));
}

// Also scan images/vip directory
const vipImages = path.join(ROOT, 'assets/images/vip');
if (fs.existsSync(vipImages)) {
  const entries = fs.readdirSync(vipImages, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.isFile()) {
      addAsset(path.join(vipImages, entry.name));
    }
  }
}

console.log(`Total assets collected: ${assets.length}`);

// Generate SQL
const now = new Date().toISOString();
const rows = assets.map(a => {
  const id = crypto.randomUUID();
  const escName = a.name.replace(/'/g, "''");
  const escCat = a.category.replace(/'/g, "''");
  const escSub = (a.subcategory || '').replace(/'/g, "''");
  const escPath = a.localPath.replace(/'/g, "''");
  return `('${id}', '${a.key}', '${escName}', '${a.type}', '${escCat}', '${escSub}', '${escPath}', NULL, NULL, '${a.mime}', ${a.size}, NULL, NULL, ${a.sortOrder}, true, '${now}', '${now}')`;
});

// Split into chunks of 200
const CHUNK_SIZE = 200;
const sqlParts = [];
for (let i = 0; i < rows.length; i += CHUNK_SIZE) {
  const chunk = rows.slice(i, i + CHUNK_SIZE);
  sqlParts.push(`
DELETE FROM app_assets WHERE id IN (SELECT id FROM app_assets LIMIT 0);
INSERT INTO app_assets (id, key, name, type, category, subcategory, local_path, remote_url, default_value, mime_type, file_size, width, height, sort_order, is_active, created_at, updated_at)
VALUES
${chunk.join(',\n')}
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name, type = EXCLUDED.type, category = EXCLUDED.category,
  subcategory = EXCLUDED.subcategory, local_path = EXCLUDED.local_path,
  mime_type = EXCLUDED.mime_type, file_size = EXCLUDED.file_size,
  sort_order = EXCLUDED.sort_order, updated_at = EXCLUDED.updated_at;
`);
}

// Write to file
const finalSql = `
-- Comprehensive app_assets seed (${assets.length} assets)
-- Generated ${now}

TRUNCATE TABLE app_assets;

${rows.join(',\n')};
`;

fs.writeFileSync(OUTPUT, finalSql, 'utf-8');
console.log(`SQL written to: ${OUTPUT}`);
console.log(`File size: ${(fs.statSync(OUTPUT).size / 1024).toFixed(1)} KB`);

// Print category summary
const byCat = {};
for (const a of assets) {
  if (!byCat[a.category]) byCat[a.category] = { count: 0, examples: [] };
  byCat[a.category].count++;
  if (byCat[a.category].examples.length < 3) byCat[a.category].examples.push(a.key);
}
console.log('\n=== CATEGORY SUMMARY ===');
for (const [cat, info] of Object.entries(byCat).sort((a, b) => b[1].count - a[1].count)) {
  console.log(`  ${cat}: ${info.count} (e.g. ${info.examples.join(', ')})`);
}
