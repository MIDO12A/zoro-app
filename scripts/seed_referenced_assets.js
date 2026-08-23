/**
 * Seed ALL images referenced in Flutter code to app_assets table.
 * Uses the existing seed_all_assets.js scanner but focuses on
 * assets that are actually referenced in the code (R.dart, Image.asset calls).
 */

const fs = require('fs');
const path = require('path');

const ASSET_DIR = path.resolve(__dirname, '..', 'assets');
const SEED_FILE = path.resolve(__dirname, '..', 'supabase', 'migrations', '20250618_seed_referenced_assets.sql');

// Asset directories declared in pubspec.yaml
const DIRS = [
  'mipmap-xxhdpi',
  'mipmap-hdpi',
  'drawable',
  'drawable-ldrtl',
  'drawable-ldrtl-xxhdpi',
  'drawable-mdpi',
  'drawable-nodpi',
  'drawable-xxhdpi',
  'drawable-xxxhdpi',
  'svga',
  'lottie',
  'vip',
  'vap',
  'raw',
  'chatbuildinemojis',
  'images/vip/vipCard',
  'anim',
  'color',
  'lang',
  'websvga',
  'websvgahead',
  'websvgaheadcircle',
];

// Android library cruft to exclude
const EXCLUDE_PREFIXES = [
  'abc_', 'mtrl_', 'm3_', 'firebase_', 'google_', 'material_', 
  'design_', 'notification_', 'common_', 'com_', 'android_',
];

function scanDirectory(dirPath, prefix = '') {
  const results = [];
  try {
    const entries = fs.readdirSync(dirPath, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.isDirectory()) {
        results.push(...scanDirectory(path.join(dirPath, entry.name), `${prefix}${entry.name}/`));
      } else if (entry.isFile()) {
        results.push(`${prefix}${entry.name}`);
      }
    }
  } catch (e) {
    // Directory doesn't exist
  }
  return results;
}

const SCREEN_PATTERNS = [
  // Order matters: more specific first
  { re: /\/(room|mic|seat|gift|game|function|set_|create_|camera|emoj)_/i, cat: 'الغرفة', sub: 'الغرفة' },
  { re: /\/(chat|msg|message|bubble)_/i, cat: 'الشات', sub: 'الشات' },
  { re: /\/discover_/i, cat: 'الاستكشاف', sub: 'استكشاف' },
  { re: /\/tab_/, cat: 'الصفحة الرئيسية', sub: 'تبويبات' },
  { re: /\/(mine_|profile_|account_|userinfo_|backpack_)/i, cat: 'حسابي', sub: 'حسابي' },
  { re: /\/login_/i, cat: 'تسجيل الدخول', sub: 'تسجيل الدخول' },
  { re: /\/rank_/i, cat: 'الترتيب', sub: 'ترتيب' },
  { re: /\/(level_|graduation_)/i, cat: 'المستوى', sub: 'مستوى' },
  { re: /\/music_/i, cat: 'الموسيقى', sub: 'موسيقى' },
  { re: /\/(vip_|ico_vip_|img_vip_)/i, cat: 'العضويات', sub: 'VIP' },
  { re: /\/(union_|agency_)/i, cat: 'النقابات', sub: 'نقابات' },
  { re: /\/(mall_|shop_|buy_)/i, cat: 'المتجر', sub: 'متجر' },
  { re: /\/(wallet_|coin_|diamond_)/i, cat: 'المحفظة', sub: 'محفظة' },
  { re: /\/(photo_|camera_|gallery_|album_|image_|img_ask|img_add)/i, cat: 'الصور', sub: 'صور' },
  { re: /\/(setting_|about_|feedback_|bind_phone)/i, cat: 'الإعدادات', sub: 'إعدادات' },
  { re: /\/(report_|blacklist_)/i, cat: 'حسابي', sub: 'بلاغات' },
  { re: /\/(emoji_|emoj_)/i, cat: 'الإيموجي', sub: 'إيموجي' },
  { re: /\/(splash_|ic_launcher)/i, cat: 'تسجيل الدخول', sub: 'شاشة البداية' },
  { re: /\/(back_|next_)/i, cat: 'عام', sub: 'أزرار' },
  { re: /\/(common_|ic_)/i, cat: 'عام', sub: 'أيقونات مشتركة' },
  { re: /\/(ava_|sex_|male|female)/i, cat: 'عام', sub: 'صور افتراضية' },
  { re: /\/(bg_)/i, cat: 'عام', sub: 'خلفيات' },
  { re: /\/(img_|banner_|label_)/i, cat: 'عام', sub: 'صور' },
  { re: /\/(user_|member_)/i, cat: 'عام', sub: 'المستخدم' },
];

function categorizeAsset(relPath) {
  const lower = relPath.toLowerCase();

  // Directory-based first (very specific)
  if (lower.startsWith('svga')) return { category: 'الغرفة', sub: 'SVGA' };
  if (lower.startsWith('lottie')) return { category: 'الغرفة', sub: 'لوتي' };
  if (lower.startsWith('vap')) return { category: 'الغرفة', sub: 'VAP' };
  if (lower.startsWith('vip') || lower.startsWith('images/vip')) return { category: 'العضويات', sub: 'صور VIP' };
  if (lower.startsWith('chatbuildinemojis')) return { category: 'الإيموجي', sub: 'إيموجي مدمج' };
  if (lower.startsWith('raw')) return { category: 'الغرفة', sub: 'مؤثرات صوتية' };
  if (lower.startsWith('anim')) return { category: 'واجهة', sub: 'حركات' };
  if (lower.startsWith('color')) return { category: 'واجهة', sub: 'ألوان XML' };
  if (lower.startsWith('lang')) return { category: 'الإعدادات', sub: 'لغات' };
  if (lower.startsWith('websvga')) return { category: 'الغرفة', sub: 'SVGA ويب' };
  if (lower.startsWith('mipmap-hdpi')) return { category: 'عام', sub: 'أيقونات' };
  // For drawable PNG files, try screen patterns
  if (lower.startsWith('drawable') && /\.(png|webp|jpg|jpeg|gif)$/i.test(lower)) {
    for (const p of SCREEN_PATTERNS) {
      if (p.re.test(lower)) return { category: p.cat, sub: p.sub };
    }
  }
  if (lower.startsWith('drawable')) return { category: 'واجهة', sub: 'أشكال XML' };

  // Screen-based patterns for mipmap-xxhdpi
  for (const p of SCREEN_PATTERNS) {
    if (p.re.test(lower)) return { category: p.cat, sub: p.sub };
  }

  return { category: 'عام', sub: 'أخرى' };
}

function detectType(relPath) {
  const ext = path.extname(relPath).toLowerCase();
  const map = {
    '.png': 'image', '.webp': 'image', '.jpg': 'image', '.jpeg': 'image',
    '.gif': 'image', '.svg': 'image', '.bmp': 'image',
    '.svga': 'svga',
    '.vap': 'vap',
    '.mp4': 'mp4',
    '.json': 'lottie',
    '.mp3': 'mp3',
    '.wav': 'wav',
    '.xml': 'css',
    '.css': 'css',
    '.js': 'js',
    '.html': 'html',
  };
  return map[ext] || 'other';
}

function getFileSize(relPath) {
  try {
    const fullPath = path.join(ASSET_DIR, relPath);
    return fs.statSync(fullPath).size;
  } catch { return 0; }
}

function mimeType(relPath) {
  const ext = path.extname(relPath).toLowerCase();
  const map = {
    '.png': 'image/png', '.webp': 'image/webp', '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.svg': 'image/svg+xml',
    '.svga': 'application/octet-stream',
    '.vap': 'video/mp4',
    '.mp4': 'video/mp4',
    '.json': 'application/json',
    '.mp3': 'audio/mpeg',
    '.wav': 'audio/wav',
    '.xml': 'application/xml',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.html': 'text/html',
  };
  return map[ext] || 'application/octet-stream';
}

function main() {
  let totalFiles = 0;
  let insertedFiles = 0;
  const rows = [];

  for (const dir of DIRS) {
    const dirPath = path.join(ASSET_DIR, dir);
    if (!fs.existsSync(dirPath)) {
      console.log(`Skipping ${dir} (not found)`);
      continue;
    }
    const files = scanDirectory(dirPath);
    console.log(`Scanning ${dir}: ${files.length} files`);
    totalFiles += files.length;

    for (const f of files) {
      const relPath = `${dir}/${f}`;
      const name = path.basename(f);
      const ext = path.extname(f).toLowerCase();

      // Skip Android library cruft
      const hasLibPrefix = EXCLUDE_PREFIXES.some(p => name.startsWith(p) || f.startsWith(p));
      if (hasLibPrefix) continue;

      const key = relPath.replace(/[\/\.]/g, '_').replace(/[^a-zA-Z0-9_]/g, '_');
      const { category, sub } = categorizeAsset(relPath);
      const type = detectType(relPath);
      const size = getFileSize(relPath);

      rows.push({
        key,
        name: name.replace(/\.[^.]+$/, ''),
        type,
        category,
        subcategory: sub,
        local_path: relPath,
        remote_url: null,
        default_value: null,
        mime_type: mimeType(relPath),
        file_size: size,
        width: null,
        height: null,
        sort_order: 0,
        is_active: true,
      });
      insertedFiles++;
    }
  }

  // Generate SQL in upsert format (matching execute_seed.js expectations)
  let sql = `-- Seed ALL referenced assets (${insertedFiles} assets)\n`;
  sql += `-- Generated: ${new Date().toISOString()}\n\n`;
  sql += `INSERT INTO app_assets (id, key, name, type, category, subcategory, local_path, remote_url, default_value, mime_type, file_size, width, height, sort_order, is_active, created_at, updated_at)\nVALUES\n`;

  const now = new Date().toISOString();
  const valueRows = rows.map(r => {
    const id = crypto.randomUUID ? crypto.randomUUID() : (require('uuid') ? require('uuid').v4() : 'gen_' + r.key);
    const vals = [
      `'${id}'`,
      `'${r.key.replace(/'/g, "''")}'`,
      `'${r.name.replace(/'/g, "''")}'`,
      `'${r.type}'`,
      `'${r.category.replace(/'/g, "''")}'`,
      `'${r.subcategory.replace(/'/g, "''")}'`,
      `'${r.local_path.replace(/'/g, "''")}'`,
      'NULL',
      'NULL',
      `'${r.mime_type}'`,
      r.file_size,
      'NULL',
      'NULL',
      r.sort_order,
      'true',
      `'${now}'`,
      `'${now}'`,
    ];
    return `  (${vals.join(', ')})`;
  });

  sql += valueRows.join(',\n');
  sql += `,\nON CONFLICT (key) DO UPDATE SET\n`;
  sql += `  name = EXCLUDED.name, type = EXCLUDED.type, category = EXCLUDED.category,\n`;
  sql += `  subcategory = EXCLUDED.subcategory, local_path = EXCLUDED.local_path,\n`;
  sql += `  mime_type = EXCLUDED.mime_type, file_size = EXCLUDED.file_size,\n`;
  sql += `  sort_order = EXCLUDED.sort_order, updated_at = EXCLUDED.updated_at;\n`;

  fs.writeFileSync(SEED_FILE, sql, 'utf-8');
  console.log(`\n✅ Total files scanned: ${totalFiles}`);
  console.log(`✅ Files inserted (non-library): ${insertedFiles}`);
  console.log(`✅ SQL written to: ${SEED_FILE}`);
  console.log(`✅ File size: ${(sql.length / 1024).toFixed(0)} KB`);
}

main();
