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
  const chunks = [
    // 1. Create store_items if not exists
    `CREATE TABLE IF NOT EXISTS public.store_items (
      item_id       TEXT PRIMARY KEY,
      name          TEXT,
      category      TEXT,
      icon_asset    TEXT,
      price         INT,
      svga_asset    TEXT,
      video_asset   TEXT,
      is_premium    BOOLEAN DEFAULT false,
      name_key      TEXT,
      photo_key     TEXT,
      default_image TEXT
    )`,

    // 2. Add video_asset column (safe re-run)
    `ALTER TABLE public.store_items ADD COLUMN IF NOT EXISTS video_asset TEXT`,

    // 3. RLS for store_items
    `ALTER TABLE public.store_items ENABLE ROW LEVEL SECURITY`,
    `DROP POLICY IF EXISTS store_items_select ON public.store_items`,
    `CREATE POLICY store_items_select ON public.store_items FOR SELECT TO authenticated, anon USING (true)`,
    `DROP POLICY IF EXISTS store_items_all ON public.store_items`,
    `CREATE POLICY store_items_all ON public.store_items FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,

    // 4. Realtime (without IF NOT EXISTS for PG < 15)
    `DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'store_items') THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.store_items; END IF; END $$`,

    // 5. Create gifted_items if not exists
    `CREATE TABLE IF NOT EXISTS public.gifted_items (
      id            TEXT PRIMARY KEY,
      uid           TEXT,
      item_id       TEXT,
      item_category TEXT,
      item_name     TEXT,
      item_icon     TEXT,
      svga_asset    TEXT,
      video_asset   TEXT,
      sent_by       TEXT,
      sent_by_name  TEXT,
      sent_at       TIMESTAMPTZ DEFAULT NOW(),
      expires_at    TIMESTAMPTZ
    )`,

    // 6. Add video_asset column
    `ALTER TABLE public.gifted_items ADD COLUMN IF NOT EXISTS video_asset TEXT`,

    // 7. Index
    `CREATE INDEX IF NOT EXISTS idx_gifted_items_uid ON public.gifted_items(uid)`,

    // 8. RLS for gifted_items (cast auth.uid() to text for TEXT column)
    `ALTER TABLE public.gifted_items ENABLE ROW LEVEL SECURITY`,
    `DROP POLICY IF EXISTS gifted_items_select ON public.gifted_items`,
    `CREATE POLICY gifted_items_select ON public.gifted_items FOR SELECT TO authenticated USING (uid = auth.uid()::text OR public._is_admin(auth.uid()))`,
    `DROP POLICY IF EXISTS gifted_items_insert ON public.gifted_items`,
    `CREATE POLICY gifted_items_insert ON public.gifted_items FOR INSERT TO authenticated WITH CHECK (uid = auth.uid()::text OR public._is_admin(auth.uid()))`,
    `DROP POLICY IF EXISTS gifted_items_delete ON public.gifted_items`,
    `CREATE POLICY gifted_items_delete ON public.gifted_items FOR DELETE TO authenticated USING (uid = auth.uid()::text OR public._is_admin(auth.uid()))`,

    // 9. Realtime
    `DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'gifted_items') THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.gifted_items; END IF; END $$`,
  ];

  console.log(`Executing ${chunks.length} SQL statements...\n`);
  for (let i = 0; i < chunks.length; i++) {
    const label = chunks[i].split('\n')[0].trim().slice(0, 90);
    process.stdout.write(`[${i + 1}/${chunks.length}] ${label}... `);
    const r = await query(chunks[i]);
    if (r.ok) {
      console.log('OK');
    } else {
      const err = r.text.slice(0, 200);
      console.log(`ERROR: ${err}`);
    }
    await new Promise(r => setTimeout(r, 200));
  }
  console.log('\nDone.');
}
main().catch(e => console.error(e));
