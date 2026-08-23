const fs = require('fs');
const path = require('path');

const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';

// Read the SQL file and extract just the value rows
const sql = fs.readFileSync(path.join(__dirname, '..', 'supabase', 'migrations', '20250618_seed_referenced_assets.sql'), 'utf-8');
const allLines = sql.split('\n');

// Find value rows (start with '(')
const valueRows = allLines.filter(l => l.trim().startsWith('(') && l.trim().endsWith('),') || l.trim().endsWith(');'));
// Clean trailing comma/semicolon
const cleanRows = valueRows.map(l => l.trim().replace(/,$/, '').replace(/;$/, ''));

console.log(`Found ${cleanRows.length} value rows`);

// Chunk into groups of 150
const CHUNK = 150;
const chunks = [];
for (let i = 0; i < cleanRows.length; i += CHUNK) {
  chunks.push(cleanRows.slice(i, i + CHUNK));
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
  // First chunk: TRUNCATE + INSERT 150 rows
  console.log('Chunk 1: TRUNCATE + 150 rows...');
  const firstSQL = `TRUNCATE TABLE app_assets;
INSERT INTO app_assets (id, key, name, type, category, subcategory, local_path, remote_url, default_value, mime_type, file_size, width, height, sort_order, is_active, created_at, updated_at)
VALUES
${chunks[0].join(',\n')}
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name, type = EXCLUDED.type, category = EXCLUDED.category,
  subcategory = EXCLUDED.subcategory, local_path = EXCLUDED.local_path,
  mime_type = EXCLUDED.mime_type, file_size = EXCLUDED.file_size,
  sort_order = EXCLUDED.sort_order, updated_at = EXCLUDED.updated_at;`;
  
  let r = await query(firstSQL);
  console.log(`  Status: ${r.ok ? 'OK' : 'FAIL'}, Response: ${r.text.slice(0, 100)}`);
  if (!r.ok) { console.log('FULL:', r.text.slice(0, 500)); return; }

  // Remaining chunks: just INSERT
  for (let i = 1; i < chunks.length; i++) {
    const insertSQL = `INSERT INTO app_assets (id, key, name, type, category, subcategory, local_path, remote_url, default_value, mime_type, file_size, width, height, sort_order, is_active, created_at, updated_at)
VALUES
${chunks[i].join(',\n')}
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name, type = EXCLUDED.type, category = EXCLUDED.category,
  subcategory = EXCLUDED.subcategory, local_path = EXCLUDED.local_path,
  mime_type = EXCLUDED.mime_type, file_size = EXCLUDED.file_size,
  sort_order = EXCLUDED.sort_order, updated_at = EXCLUDED.updated_at;`;
    
    r = await query(insertSQL);
    console.log(`Chunk ${i+1}: ${r.ok ? 'OK' : 'FAIL'}`);
    if (!r.ok) {
      console.log('  Error:', r.text.slice(0, 300));
      console.log('  Aborting.');
      break;
    }
    await new Promise(r => setTimeout(r, 300));
  }

  // Verify final count
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
