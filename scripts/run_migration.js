// Execute migration SQL directly via Supabase Management API
const sql = `ALTER TABLE public.users ADD COLUMN IF NOT EXISTS profile_bg_url TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS active_frame TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS owned_level_frames JSONB DEFAULT '[]';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS owned_level_badges JSONB DEFAULT '[]';`;

async function run() {
  const ref = 'mbdrysnfohknquevulif';
  const mgmtToken = process.env.SUPABASE_MGMT_TOKEN;

  const r = await fetch('https://api.supabase.com/v1/projects/' + ref + '/database/query', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + mgmtToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  const text = await r.text();
  if (r.ok) {
    console.log('Migration OK');
  } else {
    console.error('Migration FAILED:', text);
    console.log('\nRun this SQL manually in Supabase SQL Editor:\n');
    console.log(sql);
  }
}
run().catch(console.error);
