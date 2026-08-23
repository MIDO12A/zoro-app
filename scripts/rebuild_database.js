// Rebuild the ENTIRE database (schema + seeds) on the site's Supabase project.
//
// USAGE:
//   $env:SUPABASE_MGMT_TOKEN="sbp_your_fresh_token"
//   node scripts/rebuild_database.js
//
//   # optionally include the big asset seed files (needed for app content):
//   $env:INCLUDE_SEEDS="true"
//   node scripts/rebuild_database.js
//
// Get a fresh token from: https://app.supabase.com/account/tokens
// Project ref can be overridden: node scripts/rebuild_database.js mnpoiobmargjlnxwczgi

const REF = process.argv[2] || 'mnpoiobmargjlnxwczgi';
const TOKEN = process.env.SUPABASE_MGMT_TOKEN;
const INCLUDE_SEEDS = process.env.INCLUDE_SEEDS === 'true';

const fs = require('fs');
const path = require('path');

if (!TOKEN) {
  console.error('❌ Missing SUPABASE_MGMT_TOKEN env var.');
  console.error('   Get a fresh token from https://app.supabase.com/account/tokens then run:');
  console.error('   $env:SUPABASE_MGMT_TOKEN="sbp_..."  ;  node scripts/rebuild_database.js');
  process.exit(1);
}

const SEED_FILES = [
  '20250615_seed_app_assets.sql',
  '20250618_seed_all_app_assets.sql',
  '20250618_seed_referenced_assets.sql',
];

async function q(sql, label) {
  const r = await fetch(`https://api.supabase.com/v1/projects/${REF}/database/query`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  const text = await r.text();
  if (r.ok) {
    console.log(`   ✔ OK  ${label} ${text.slice(0, 120)}`);
    return true;
  }
  console.log(`   ✘ ERROR ${label}: ${text.slice(0, 300)}`);
  return false;
}

async function main() {
  console.log(`=== REBUILDING DATABASE ===`);
  console.log(`Project : ${REF}`);
  console.log(`Seeds   : ${INCLUDE_SEEDS ? 'INCLUDED' : 'SKIPPED (set INCLUDE_SEEDS=true to include)'}`);
  console.log('');

  const dir = path.join(__dirname, '..', 'supabase', 'migrations');
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.sql')).sort();
  console.log(`Found ${files.length} SQL files\n`);

  let ok = 0, err = 0, skipped = 0;
  for (const file of files) {
    const isSeed = SEED_FILES.includes(file);
    if (isSeed && !INCLUDE_SEEDS) {
      console.log(`--- ${file}  (SEED - skipped, set INCLUDE_SEEDS=true)`);
      skipped++;
      continue;
    }
    console.log(`--- ${file}`);
    const sql = fs.readFileSync(path.join(dir, file), 'utf8');
    const good = await q(sql, file);
    good ? ok++ : err++;
    await new Promise(r => setTimeout(r, 400));
  }

  console.log(`\n=== DONE: ${ok} OK, ${err} ERRORS, ${skipped} skipped ===`);
  if (err > 0) {
    console.log('Fix the errors above and re-run (files are idempotent).');
    process.exitCode = 1;
  }
}

main().catch(e => { console.error(e); process.exit(1); });
