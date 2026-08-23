// Rebuild the ENTIRE database on the CURRENT Supabase project.
// Runs supabase_schema.sql (base tables) first, then every migration file.
//
// USAGE:
//   $env:SUPABASE_MGMT_TOKEN="sbp_your_fresh_token"
//   node scripts/rebuild_current_project.js
//
//   # include the big asset seed files:
//   $env:INCLUDE_SEEDS="true"
//   node scripts/rebuild_current_project.js
//
// Get a fresh token from: https://supabase.com/account/tokens

const REF = process.argv[2] || 'mnpoiobmargjlnxwczgi';
const TOKEN = process.env.SUPABASE_MGMT_TOKEN;
const INCLUDE_SEEDS = process.env.INCLUDE_SEEDS === 'true';

const fs = require('fs');
const path = require('path');

if (!TOKEN) {
  console.error('[X] Missing SUPABASE_MGMT_TOKEN env var.');
  console.error('    Get a fresh token from https://supabase.com/account/tokens then run:');
  console.error('    $env:SUPABASE_MGMT_TOKEN="sbp_..."  ;  node scripts/rebuild_current_project.js');
  process.exit(1);
}

const ROOT = path.join(__dirname, '..');
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
    console.log(`   [OK]  ${label} ${text.slice(0, 120)}`);
    return true;
  }
  console.log(`   [ERROR] ${label}: ${text.slice(0, 300)}`);
  return false;
}

async function main() {
  console.log('=== REBUILDING DATABASE (schema + migrations) ===');
  console.log(`Project : ${REF}`);
  console.log(`Seeds   : ${INCLUDE_SEEDS ? 'INCLUDED' : 'SKIPPED'}`);
  console.log('');

  const steps = [];

  // 1. Base schema (the big one that creates users/rooms/gifts/unions/...)
  const schemaFile = path.join(ROOT, 'supabase_schema.sql');
  if (fs.existsSync(schemaFile)) {
    steps.push({ file: 'supabase_schema.sql', sql: fs.readFileSync(schemaFile, 'utf8') });
  }

  // 2. All migration files
  const dir = path.join(ROOT, 'supabase', 'migrations');
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.sql')).sort();
  for (const file of files) {
    if (SEED_FILES.includes(file) && !INCLUDE_SEEDS) continue;
    steps.push({ file, sql: fs.readFileSync(path.join(dir, file), 'utf8') });
  }

  console.log(`Total steps: ${steps.length}\n`);

  let ok = 0, err = 0, skipped = 0;
  for (const step of steps) {
    const isSeed = SEED_FILES.includes(step.file);
    if (isSeed && !INCLUDE_SEEDS) {
      console.log(`--- ${step.file} (SEED - skipped)`);
      skipped++;
      continue;
    }
    console.log(`--- ${step.file}`);
    const good = await q(step.sql, step.file);
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
