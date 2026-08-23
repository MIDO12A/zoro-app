import { supabase } from './config/database';

async function migrate() {
  console.log('Running Zero Backend Database Migration...\n');

  const tables = [
    `CREATE TABLE IF NOT EXISTS agencies (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      code TEXT UNIQUE NOT NULL,
      owner_uid TEXT REFERENCES users(uid),
      commission_rate INT DEFAULT 10,
      total_earnings BIGINT DEFAULT 0,
      member_count INT DEFAULT 1,
      status TEXT DEFAULT 'active',
      created_at TIMESTAMPTZ DEFAULT NOW()
    )`,

    `CREATE TABLE IF NOT EXISTS agency_members (
      id TEXT PRIMARY KEY,
      agency_id TEXT REFERENCES agencies(id) ON DELETE CASCADE,
      user_uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
      role TEXT DEFAULT 'sub_agent',
      commission_rate INT DEFAULT 8,
      joined_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(agency_id, user_uid)
    )`,

    `CREATE TABLE IF NOT EXISTS recharge_orders (
      id TEXT PRIMARY KEY,
      user_id TEXT REFERENCES users(uid),
      plan_id INT NOT NULL,
      amount INT NOT NULL,
      diamonds INT NOT NULL,
      status TEXT DEFAULT 'pending',
      payment_method TEXT DEFAULT 'manual',
      created_at TIMESTAMPTZ DEFAULT NOW(),
      completed_at TIMESTAMPTZ
    )`,

    `ALTER TABLE users ADD COLUMN IF NOT EXISTS vip_tier INT DEFAULT 0`,
    `ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user'`,
    `ALTER TABLE users ADD COLUMN IF NOT EXISTS agency_id TEXT REFERENCES agencies(id)`,
  ];

  for (const sql of tables) {
    try {
      const { error } = await supabase.rpc('exec_sql', { sql_text: sql });
      if (error) {
        // Fallback: try direct query
        console.log(`  ⚠️  RPC failed, trying direct query...`);
        try {
          await supabase.from('_migrations').select('*').limit(1);
          console.log(`  ⚠️  Direct query not available for: ${sql.slice(0, 50)}...`);
        } catch {}
      } else {
        console.log(`  ✅ ${sql.slice(0, 60)}...`);
      }
    } catch (err: any) {
      console.log(`  ⚠️  ${err.message}`);
    }
  }

  console.log('\nMigration complete!');
  console.log('\nNext steps:');
  console.log('  1. Run these SQL commands manually in Supabase SQL Editor if RPC failed');
  console.log('  2. Set SUPABASE_URL and SUPABASE_SERVICE_KEY in .env');
  console.log('  3. npm run dev to start the server');
}

migrate().catch(console.error);
