const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';

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
  return { ok: r.ok, text };
}

async function main() {
  // Read all migration files and execute them
  const fs = require('fs');
  const path = require('path');
  const dir = path.join(__dirname, '..', 'supabase', 'migrations');
  const files = fs.readdirSync(dir).sort();

  // Only execute missing tables/functions migrations (skip seed files)
  const skipPatterns = ['seed_', 'app_assets'];

  let total = 0, ok = 0, errs = 0;
  for (const file of files) {
    if (skipPatterns.some(p => file.includes(p))) continue;
    const content = fs.readFileSync(path.join(dir, file), 'utf8');
    // Split by semicolons to get individual statements
    const statements = content
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 10 && !s.startsWith('--'));

    for (const stmt of statements) {
      total++;
      process.stdout.write(`[${file.slice(0, 30)}] ${stmt.slice(0, 70)}... `);
      const r = await q(stmt);
      if (r.ok) {
        ok++;
        console.log('OK');
      } else {
        errs++;
        // Only show first 100 chars of error
        console.log(`ERR: ${r.text.slice(0, 100)}`);
      }
      await new Promise(r => setTimeout(r, 100));
    }
  }
  console.log(`\nDone: ${total} statements, ${ok} OK, ${errs} errors`);
}
main().catch(e => console.error(e));
