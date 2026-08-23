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
    // ── host_diamond_ledger ──
    `CREATE TABLE IF NOT EXISTS public.host_diamond_ledger (
      id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
      host_id         uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
      agency_id       uuid        REFERENCES public.host_agencies(id),
      room_id         text,
      sender_id       uuid        REFERENCES auth.users(id),
      gift_id         uuid        REFERENCES public.gifts(id),
      gold_amount     bigint      NOT NULL CHECK (gold_amount > 0),
      diamond_gross   bigint      NOT NULL,
      diamond_host    bigint      NOT NULL,
      diamond_agency  bigint      NOT NULL DEFAULT 0,
      diamond_platform bigint     NOT NULL,
      idempotency_key text        UNIQUE,
      created_at      timestamptz NOT NULL DEFAULT now()
    )`,
    `CREATE INDEX IF NOT EXISTS hdl_host_idx ON public.host_diamond_ledger (host_id, created_at DESC)`,
    `CREATE INDEX IF NOT EXISTS hdl_agency_idx ON public.host_diamond_ledger (agency_id, created_at DESC)`,
    `ALTER TABLE public.host_diamond_ledger ENABLE ROW LEVEL SECURITY`,
    `DROP POLICY IF EXISTS hdl_host_read ON public.host_diamond_ledger`,
    `CREATE POLICY hdl_host_read ON public.host_diamond_ledger FOR SELECT TO authenticated USING (host_id = auth.uid())`,
    `DROP POLICY IF EXISTS hdl_admin ON public.host_diamond_ledger`,
    `CREATE POLICY hdl_admin ON public.host_diamond_ledger FOR ALL TO authenticated USING (public._is_admin(auth.uid())) WITH CHECK (public._is_admin(auth.uid()))`,

    // ── user_wallets ──
    `CREATE TABLE IF NOT EXISTS public.user_wallets (
      user_id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
      gold_balance    BIGINT NOT NULL DEFAULT 0 CHECK (gold_balance >= 0),
      diamond_balance BIGINT NOT NULL DEFAULT 0 CHECK (diamond_balance >= 0),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )`,
    `ALTER TABLE public.user_wallets ADD COLUMN IF NOT EXISTS gold_balance BIGINT NOT NULL DEFAULT 0 CHECK (gold_balance >= 0)`,
    `ALTER TABLE public.user_wallets ADD COLUMN IF NOT EXISTS diamond_balance BIGINT NOT NULL DEFAULT 0 CHECK (diamond_balance >= 0)`,
    `ALTER TABLE public.user_wallets ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`,
    `ALTER TABLE public.user_wallets ENABLE ROW LEVEL SECURITY`,
    `DROP POLICY IF EXISTS "wallet_select_own" ON public.user_wallets`,
    `CREATE POLICY "wallet_select_own" ON public.user_wallets FOR SELECT USING (auth.uid() = user_id)`,
    `DROP POLICY IF EXISTS "wallet_insert_own" ON public.user_wallets`,
    `CREATE POLICY "wallet_insert_own" ON public.user_wallets FOR INSERT WITH CHECK (auth.uid() = user_id)`,
  ];

  console.log(`Executing ${chunks.length} SQL statements...\n`);
  for (let i = 0; i < chunks.length; i++) {
    const label = chunks[i].split('\n')[0].trim().slice(0, 90);
    process.stdout.write(`[${i + 1}/${chunks.length}] ${label}... `);
    const r = await query(chunks[i]);
    if (r.ok) {
      console.log('OK');
    } else {
      const err = r.text.slice(0, 250);
      console.log(`ERROR: ${err}`);
    }
    await new Promise(r => setTimeout(r, 200));
  }
  console.log('\nDone.');
}
main().catch(e => console.error(e));
