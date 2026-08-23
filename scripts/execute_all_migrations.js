const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';
const fs = require('fs');
const path = require('path');

async function q(sql) {
  const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  const text = await r.text();
  return { ok: r.ok, text, sql: sql.slice(0, 80) };
}

async function main() {
  const dir = path.join(__dirname, '..', 'supabase', 'migrations');
  const files = fs.readdirSync(dir).sort();

  // Skip seed files (very large)
  const skip = ['seed_all_app_assets', 'seed_app_assets', 'seed_referenced_assets'];

  let ok = 0, err = 0;
  for (const file of files) {
    if (skip.some(s => file.includes(s))) {
      console.log(`--- ${file} (SKIPPED)\n`);
      continue;
    }
    console.log(`--- ${file}`);
    const content = fs.readFileSync(path.join(dir, file), 'utf8');
    const r = await q(content);
    if (r.ok) {
      console.log('OK\n');
      ok++;
    } else {
      console.log(`ERROR: ${r.text.slice(0, 200)}\n`);
      err++;
    }
    await new Promise(r => setTimeout(r, 300));
  }
  console.log(`\n=== DONE: ${ok} OK, ${err} ERRORS ===`);
}
main().catch(e => console.error(e));
