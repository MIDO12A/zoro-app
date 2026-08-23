const token = process.env.SUPABASE_MGMT_TOKEN;
const ref = 'mbdrysnfohknquevulif';

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
  const stmts = [
    // Add description_ar and description_en to badges
    `ALTER TABLE public.badges ADD COLUMN IF NOT EXISTS description_ar text;`,
    `ALTER TABLE public.badges ADD COLUMN IF NOT EXISTS description_en text;`,
    `ALTER TABLE public.badges ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;`,
    `ALTER TABLE public.badges ADD COLUMN IF NOT EXISTS sort_order int NOT NULL DEFAULT 0;`,
    `ALTER TABLE public.badges ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();`,
    `ALTER TABLE public.badges ADD COLUMN IF NOT EXISTS type text DEFAULT 'normal';`,

    // Add description_ar and description_en to necklaces
    `ALTER TABLE public.necklaces ADD COLUMN IF NOT EXISTS description_ar text;`,
    `ALTER TABLE public.necklaces ADD COLUMN IF NOT EXISTS description_en text;`,
    `ALTER TABLE public.necklaces ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;`,
    `ALTER TABLE public.necklaces ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();`,
  ];

  for (let i = 0; i < stmts.length; i++) {
    const label = stmts[i].trim().slice(0, 100);
    process.stdout.write(`[${i+1}/${stmts.length}] ${label}... `);
    const r = await query(stmts[i]);
    if (r.ok) {
      console.log('✅');
    } else {
      const err = r.text.slice(0, 200);
      console.log(`❌ ${err}`);
    }
    await new Promise(r => setTimeout(r, 200));
  }

  console.log('\n✅ Badge/necklace columns added!');
}

main().catch(e => console.error(e));
