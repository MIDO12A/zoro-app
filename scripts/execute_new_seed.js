const fs = require('fs');
const path = require('path');

const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';

const sql = fs.readFileSync(path.join(__dirname, '..', 'supabase', 'migrations', '20250618_seed_referenced_assets.sql'), 'utf-8');

// Extract value lines between VALUES\n and \nON CONFLICT
const vi = sql.indexOf('VALUES\n');
const oci = sql.indexOf('\nON CONFLICT');
if (vi === -1 || oci === -1) { console.error('Parse error'); process.exit(1); }

const block = sql.substring(vi + 7, oci + 1);
// Each row: "  ('uuid', 'key', ...),\n"
const rawRows = block.match(/^\s{2}\(.*?\),?$/gm);
if (!rawRows) { console.error('No rows found'); process.exit(1); }

const rows = rawRows.map(r => r.trim().replace(/,$/, ''));
console.log(`Found ${rows.length} value rows`);

const CHUNK = 150;
const chunks = [];
for (let i = 0; i < rows.length; i += CHUNK) {
  chunks.push(rows.slice(i, i + CHUNK));
}
console.log(`Split into ${chunks.length} chunks`);

async function query(sql) {
  const resp = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  const text = await resp.text();
  return { ok: resp.ok, text };
}

async function main() {
  for (let i = 0; i < chunks.length; i++) {
    const insertSQL = `INSERT INTO app_assets (id, key, name, type, category, subcategory, local_path, remote_url, default_value, mime_type, file_size, width, height, sort_order, is_active, created_at, updated_at)
VALUES
${chunks[i].join(',\n')}
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name, type = EXCLUDED.type, category = EXCLUDED.category,
  subcategory = EXCLUDED.subcategory, local_path = EXCLUDED.local_path,
  mime_type = EXCLUDED.mime_type, file_size = EXCLUDED.file_size,
  sort_order = EXCLUDED.sort_order, updated_at = EXCLUDED.updated_at;`;

    const r = await query(insertSQL);
    console.log(`Chunk ${i+1}/${chunks.length}: ${r.ok ? 'OK' : 'FAIL'}`);
    if (!r.ok) {
      console.log('  Error:', r.text.slice(0, 300));
      break;
    }
    await new Promise(r => setTimeout(r, 300));
  }

  console.log('\nVerifying count...');
  const verifyResp = await fetch('https://' + ref + '.supabase.co/rest/v1/app_assets?select=count', {
    headers: {
      'apikey': token,
      'Authorization': 'Bearer ' + token,
    }
  });
  const verifyText = await verifyResp.text();
  console.log('Count result:', verifyText);
}

main().catch(e => console.error(e));
