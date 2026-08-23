const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';

async function main() {
  // Fix gift_item category
  const fix1 = "UPDATE app_assets SET category = '\u0627\u0644\u063A\u0631\u0641\u0629' WHERE key = 'assets_mipmap_xxhdpi_gift_item_png'";
  let r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: fix1 }),
  });
  let t = await r.text();
  console.log('Fix gift_item:', r.status, t.slice(0, 100));

  // Verify count by category
  const q = "SELECT category, COUNT(*) as cnt FROM app_assets GROUP BY category ORDER BY cnt DESC";
  r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: q }),
  });
  t = await r.text();
  console.log('\nCategory breakdown:');
  const rows = JSON.parse(t);
  for (const row of rows) {
    console.log(`  ${row.category}: ${row.cnt}`);
  }
  
  // Total
  console.log(`\nTotal: ${rows.reduce((s, r) => s + parseInt(r.cnt), 0)}`);
}

main().catch(e => console.error(e));
