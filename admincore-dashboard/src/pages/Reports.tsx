import { useEffect, useState } from 'react';
import { getReports, updateReportStatus, updateUser } from '../lib/db';
import { ReportModel } from '../types';
import { ShieldAlert, Ban, CheckCircle, Clock } from 'lucide-react';

export default function Reports() {
  const [reports, setReports] = useState<ReportModel[]>([]);
  const [loading, setLoading] = useState(true);

  const loadReports = async () => {
    try {
      setLoading(true);
      const res = await getReports();
      setReports(res);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadReports();
  }, []);

  const handleBan = async (report: ReportModel) => {
    if (!confirm(`Are you sure you want to ban ${report.reportedName || report.reportedUid}?`)) return;
    try {
      await updateUser(report.reportedUid, { banned: true, banReason: `Reported: ${report.reason}` });
      await updateReportStatus(report.id, 'banned');
      await loadReports();
    } catch (err) {
      alert('Failed to ban user: ' + (err as Error).message);
    }
  };

  const handleDismiss = async (report: ReportModel) => {
    if (!confirm('Dismiss this report?')) return;
    try {
      await updateReportStatus(report.id, 'dismissed');
      await loadReports();
    } catch (err) {
      alert('Failed to dismiss: ' + (err as Error).message);
    }
  };

  return (
    <div className="space-y-6" dir="rtl">
      <div>
        <h2 className="text-white text-lg font-semibold flex items-center gap-2">
          <ShieldAlert className="w-5 h-5 text-rose-500" />
          البلاغات (Reports)
        </h2>
        <p className="text-slate-500 text-xs mt-0.5">مراجعة البلاغات المقدمة من المستخدمين وحظر المخالفين.</p>
      </div>

      {loading ? (
        <div className="text-slate-500 text-sm text-center py-10">جاري التحميل...</div>
      ) : reports.length === 0 ? (
        <div className="text-slate-500 text-sm text-center py-10">لا توجد بلاغات حالياً.</div>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {reports.map(r => (
            <div key={r.id} className="bg-[#141417] rounded-xl border border-white/5 p-4 flex flex-col gap-3">
              <div className="flex justify-between items-start">
                <div>
                  <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold ${r.status === 'pending' ? 'bg-amber-500/20 text-amber-400' : r.status === 'banned' ? 'bg-red-500/20 text-red-400' : 'bg-emerald-500/20 text-emerald-400'}`}>
                    {r.status === 'pending' ? 'قيد المراجعة' : r.status === 'banned' ? 'تم الحظر' : 'مرفوض'}
                  </span>
                  <div className="mt-2 text-white font-bold text-sm">{r.reason}</div>
                  <div className="text-[10px] text-slate-500 mt-1 flex items-center gap-1">
                    <Clock className="w-3 h-3" /> {new Date(r.createdAt || Date.now()).toLocaleString('ar')}
                  </div>
                </div>
              </div>

              <div className="text-xs text-slate-300 bg-white/5 p-2 rounded-lg">
                <span className="text-slate-500 font-bold block mb-1 text-[10px]">التفاصيل:</span>
                {r.details || 'لا توجد تفاصيل.'}
              </div>

              {r.screenshot && (
                <div>
                  <span className="text-slate-500 font-bold block mb-1 text-[10px]">صورة الإثبات:</span>
                  <a href={r.screenshot} target="_blank" rel="noreferrer">
                    <img src={r.screenshot} alt="Screenshot" className="w-full h-32 object-cover rounded-lg border border-white/10 hover:opacity-80 transition-opacity" />
                  </a>
                </div>
              )}

              <div className="bg-[#1a1a1e] rounded-lg p-2 text-[10px]">
                <div className="flex justify-between border-b border-white/5 pb-1 mb-1">
                  <span className="text-slate-500">المُبلغ (Reporter):</span>
                  <span className="text-white font-mono">{r.reporterUid}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">المُبلغ عنه (Reported):</span>
                  <span className="text-white font-mono">{r.reportedName || r.reportedUid}</span>
                </div>
              </div>

              {r.status === 'pending' && (
                <div className="flex gap-2 mt-auto pt-2">
                  <button onClick={() => handleBan(r)} className="flex-1 bg-red-600 hover:bg-red-700 text-white text-xs font-bold py-2 rounded-lg flex justify-center items-center gap-1 transition-colors">
                    <Ban className="w-4 h-4" /> حظر المستخدم
                  </button>
                  <button onClick={() => handleDismiss(r)} className="flex-1 bg-slate-700 hover:bg-slate-600 text-white text-xs font-bold py-2 rounded-lg flex justify-center items-center gap-1 transition-colors">
                    <CheckCircle className="w-4 h-4" /> تجاهل
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
