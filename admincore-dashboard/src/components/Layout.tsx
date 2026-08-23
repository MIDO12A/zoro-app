import { useState, useEffect, useCallback } from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import Header from './Header';
import { onAuthChange } from '../lib/auth';
import { ensureAdminBootstrap, getAdminStatus } from '../lib/supabase';

export default function Layout() {
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [uid, setUid] = useState<string | null>(null);
  const [status, setStatus] = useState<{ fixed: boolean; reason: string } | null>(null);
  const [busy, setBusy] = useState(false);

  const check = useCallback(async (u: string) => {
    const s = await getAdminStatus(u);
    setStatus({ fixed: s.fixed, reason: s.reason });
  }, []);

  useEffect(() => {
    const unsub = onAuthChange(u => {
      setUid(u?.id ?? null);
      setStatus(null);
      if (u) check(u.id);
    });
    return unsub;
  }, [check]);

  const runBootstrap = async () => {
    if (!uid) return;
    setBusy(true);
    try {
      const r = await ensureAdminBootstrap(uid);
      if (r.created) setStatus({ fixed: true, reason: 'ok' });
      else await check(uid);
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    const mq = window.matchMedia('(max-width: 1023px)');
    const handler = (e: MediaQueryListEvent | MediaQueryList) => {
      if (e.matches) setCollapsed(true);
    };
    handler(mq);
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, []);

  return (
    <div className="min-h-screen bg-[#0A0A0B] text-slate-300 flex">
      <Sidebar collapsed={collapsed} onToggle={() => setCollapsed(c => !c)} mobileOpen={mobileOpen} onMobileClose={() => setMobileOpen(false)} />
      {/* Mobile overlay backdrop */}
      {mobileOpen && <div className="fixed inset-0 bg-black/50 z-10 lg:hidden" onClick={() => setMobileOpen(true)} />}
      <div className="flex-1 flex flex-col min-w-0">
        <Header onMenuClick={() => setMobileOpen(true)} />
        {status && !status.fixed && (
          <div className="mx-3 mt-3 lg:mx-6 lg:mt-4 rounded-lg border border-red-500/30 bg-red-500/10 px-3 py-2 text-xs text-red-200 flex flex-wrap items-center gap-2">
            <span className="font-bold">⚠️ Admin write access blocked</span>
            <span className="opacity-80 break-all flex-1 min-w-[200px]">{status.reason}</span>
            <button
              onClick={runBootstrap}
              disabled={busy}
              className="px-3 py-1 rounded bg-red-500/20 hover:bg-red-500/30 border border-red-500/40 disabled:opacity-50 whitespace-nowrap"
            >
              {busy ? 'Running...' : 'Run bootstrap'}
            </button>
            {uid && <code className="opacity-60 whitespace-nowrap">uid: {uid}</code>}
          </div>
        )}
        <main className="flex-1 overflow-y-auto p-3 lg:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
