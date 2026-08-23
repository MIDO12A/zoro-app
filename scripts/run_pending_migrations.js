async function runMigration() {
  const ref = 'mbdrysnfohknquevulif';
  const fs = require('fs');
  const path = require('path');

  // === CONFIG ===
  // Get a fresh token from https://app.supabase.com/account/tokens
  // Paste it below (without quotes):
  const mgmtToken = process.env.SUPABASE_MGMT_TOKEN || process.env.SUPABASE_MGMT_TOKEN;

  const sqlPath = path.join(__dirname, '..', 'supabase', 'migrations', 'PENDING_MIGRATIONS.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');

  console.log('Attempting to execute PENDING_MIGRATIONS.sql via Management API...\n');

  const r = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${mgmtToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });

  const text = await r.text();
  if (r.ok) {
    console.log('✅ Migration executed successfully!');
    console.log('Response:', text.slice(0, 200));
  } else {
    console.log('❌ Management API failed:', text.slice(0, 300));
    console.log('\n========================================');
    console.log('⚠️  To fix manually:');
    console.log('   1. Open https://supabase.com/dashboard/project/mbdrysnfohknquevulif/sql/new');
    console.log('   2. Copy the content of: supabase/migrations/PENDING_MIGRATIONS.sql');
    console.log('   3. Paste into SQL Editor and click "Run"');
    console.log('========================================');
    console.log('\n💡 To retry with a fresh token:');
    console.log('   $env:SUPABASE_MGMT_TOKEN="sbp_your_new_token_here"');
    console.log('   node scripts/run_pending_migrations.js');
  }
}

runMigration().catch(console.error);
