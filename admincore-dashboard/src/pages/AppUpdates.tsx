import { useEffect, useRef, useState } from 'react';
import { Rocket, Upload, CloudUpload, Trash2, CheckCircle2, AlertTriangle } from 'lucide-react';
import { getAppUpdate, publishAppUpdate, unpublishAppUpdate } from '../lib/db';
import { uploadToCloudinary } from '../lib/storage';
import type { AppUpdateConfig } from '../lib/db';

const emptyForm: AppUpdateConfig = {
  latest_version: '',
  build_number: 1,
  apk_url: '',
  notes_ar: '',
  notes_en: '',
  force_update: false,
};

export default function AppUpdates() {
  const [form, setForm] = useState<AppUpdateConfig>({ ...emptyForm });
  const [published, setPublished] = useState<AppUpdateConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [uploadPct, setUploadPct] = useState(0);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    (async () => {
      const cur = await getAppUpdate();
      if (cur) {
        setPublished(cur);
        setForm({
          latest_version: cur.latest_version || '',
          build_number: Number(cur.build_number) || 1,
          apk_url: cur.apk_url || '',
          notes_ar: cur.notes_ar || '',
          notes_en: cur.notes_en || '',
          force_update: !!cur.force_update,
        });
      }
      setLoading(false);
    })();
  }, []);

  const set = <K extends keyof AppUpdateConfig>(k: K, v: AppUpdateConfig[K]) =>
    setForm(f => ({ ...f, [k]: v }));

  const onPickApk = async (file: File) => {
    if (!file.name.toLowerCase().endsWith('.apk')) {
      setMsg({ ok: false, text: 'اختر ملف APK صالح / Pick a valid .apk file' });
      return;
    }
    setUploading(true);
    setUploadPct(0);
    setMsg(null);
    try {
      const url = await uploadToCloudinary(file, 'app_updates', p => setUploadPct(p));
      if (url) {
        set('apk_url', url);
        setMsg({ ok: true, text: 'تم رفع الـ APK بنجاح ✓' });
      } else {
        setMsg({ ok: false, text: 'فشل الرفع — جرّب لصق رابط مباشر بدلاً من الرفع' });
      }
    } catch {
      setMsg({ ok: false, text: 'فشل رفع الملف (قد يكون أكبر من الحد المسموح) — استخدم رابط مباشر' });
    }
    setUploading(false);
  };

  const publish = async () => {
    if (!form.latest_version.trim() || !form.apk_url.trim()) {
      setMsg({ ok: false, text: 'أدخل رقم الإصدار ورابط الـ APK أولاً' });
      return;
    }
    setSaving(true);
    setMsg(null);
    const err = await publishAppUpdate({ ...form, build_number: Number(form.build_number) || 1 });
    setSaving(false);
    if (err) {
      setMsg({ ok: false, text: `فشل النشر: ${err}` });
      return;
    }
    const cur = await getAppUpdate();
    setPublished(cur);
    setMsg({ ok: true, text: 'تم نشر التحديث — كل المستخدمين هيشوفوه مع أول تشغيل للتطبيق ✓' });
  };

  const unpublish = async () => {
    setSaving(true);
    const err = await unpublishAppUpdate();
    setSaving(false);
    if (err) {
      setMsg({ ok: false, text: `فشل إلغاء النشر: ${err}` });
      return;
    }
    setPublished(null);
    setForm({ ...emptyForm });
    setMsg({ ok: true, text: 'تم إلغاء نشر التحديث' });
  };

  const inputCls =
    'w-full bg-[#141416] border border-white/10 rounded-lg px-3 py-2.5 text-sm text-slate-200 outline-none focus:border-purple-500/60';
  const labelCls = 'block text-xs font-medium text-slate-400 mb-1.5';

  if (loading) {
    return <div className="p-8 text-slate-500 text-sm">Loading...</div>;
  }

  return (
    <div className="p-6 max-w-3xl mx-auto space-y-6">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-purple-600/20 flex items-center justify-center">
          <Rocket className="text-purple-400" size={20} />
        </div>
        <div>
          <h1 className="text-lg font-bold text-slate-100">تحديثات التطبيق / App Updates</h1>
          <p className="text-xs text-slate-500">
            انشر إصدار جديد وكل المستخدمين هيوصلكم تنبيه تحديث مباشر داخل التطبيق
          </p>
        </div>
      </div>

      {published && (
        <div className="bg-emerald-500/10 border border-emerald-500/30 rounded-xl px-4 py-3 flex items-start gap-3">
          <CheckCircle2 className="text-emerald-400 mt-0.5" size={18} />
          <div className="text-sm">
            <div className="text-emerald-300 font-semibold">
              تحديث منشور حالياً — v{published.latest_version} (build {published.build_number})
              {published.force_update ? ' — إلزامي' : ''}
            </div>
            {published.published_at && (
              <div className="text-emerald-500/70 text-xs mt-0.5">
                نُشر في: {new Date(published.published_at).toLocaleString()}
              </div>
            )}
          </div>
        </div>
      )}

      {msg && (
        <div
          className={`rounded-xl px-4 py-3 text-sm flex items-center gap-2 border ${
            msg.ok
              ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-300'
              : 'bg-red-500/10 border-red-500/30 text-red-300'
          }`}
        >
          {msg.ok ? <CheckCircle2 size={16} /> : <AlertTriangle size={16} />}
          {msg.text}
        </div>
      )}

      <div className="bg-[#101012] border border-white/5 rounded-2xl p-6 space-y-5">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className={labelCls}>رقم الإصدار (latest_version)</label>
            <input
              className={inputCls}
              placeholder="1.1.0"
              value={form.latest_version}
              onChange={e => set('latest_version', e.target.value)}
            />
          </div>
          <div>
            <label className={labelCls}>Build number</label>
            <input
              type="number"
              className={inputCls}
              value={form.build_number}
              onChange={e => set('build_number', Number(e.target.value))}
            />
          </div>
        </div>

        <div>
          <label className={labelCls}>ملف APK</label>
          <div className="flex gap-2">
            <button
              onClick={() => fileRef.current?.click()}
              disabled={uploading}
              className="flex items-center gap-2 bg-white/5 hover:bg-white/10 disabled:opacity-50 border border-white/10 rounded-lg px-4 py-2.5 text-sm text-slate-200"
            >
              <CloudUpload size={16} />
              {uploading ? `جاري الرفع... ${uploadPct}%` : 'رفع APK'}
            </button>
            <input
              ref={fileRef}
              type="file"
              accept=".apk"
              className="hidden"
              onChange={e => {
                const f = e.target.files?.[0];
                if (f) onPickApk(f);
                e.target.value = '';
              }}
            />
          </div>
          {uploading && (
            <div className="mt-2 h-1.5 bg-white/5 rounded-full overflow-hidden">
              <div
                className="h-full bg-purple-500 transition-all"
                style={{ width: `${uploadPct}%` }}
              />
            </div>
          )}
          <input
            className={`${inputCls} mt-3`}
            dir="ltr"
            placeholder="https://... (رابط مباشر للـ APK)"
            value={form.apk_url}
            onChange={e => set('apk_url', e.target.value)}
          />
          <p className="text-[11px] text-slate-600 mt-1.5">
            ارفع الملف من الزر أو الصق رابطاً مباشراً (GitHub Releases مثلاً لو حجم الملف كبير)
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className={labelCls}>ملاحظات التحديث (عربي)</label>
            <textarea
              rows={4}
              className={inputCls}
              value={form.notes_ar}
              onChange={e => set('notes_ar', e.target.value)}
            />
          </div>
          <div>
            <label className={labelCls}>Release notes (English)</label>
            <textarea
              rows={4}
              className={inputCls}
              value={form.notes_en}
              onChange={e => set('notes_en', e.target.value)}
            />
          </div>
        </div>

        <label className="flex items-center gap-2.5 cursor-pointer select-none">
          <input
            type="checkbox"
            checked={form.force_update}
            onChange={e => set('force_update', e.target.checked)}
            className="w-4 h-4 accent-purple-500"
          />
          <span className="text-sm text-slate-300">
            تحديث إلزامي — منع المستخدمين من الدخول بدون تحديث
          </span>
        </label>

        <div className="flex gap-3 pt-2">
          <button
            onClick={publish}
            disabled={saving || uploading}
            className="flex items-center gap-2 bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white rounded-lg px-5 py-2.5 text-sm font-semibold"
          >
            <Rocket size={16} />
            {saving ? '...' : published ? 'تحديث النشر' : 'نشر التحديث'}
          </button>
          {published && (
            <button
              onClick={unpublish}
              disabled={saving}
              className="flex items-center gap-2 bg-red-600/15 hover:bg-red-600/25 text-red-300 border border-red-500/30 rounded-lg px-5 py-2.5 text-sm"
            >
              <Trash2 size={16} />
              إلغاء النشر
            </button>
          )}
        </div>
      </div>

      <div className="bg-[#101012] border border-white/5 rounded-2xl p-5 text-xs text-slate-500 leading-relaxed">
        <div className="flex items-center gap-2 mb-2 text-slate-400 font-semibold">
          <Upload size={14} /> خطوات النشر
        </div>
        1) اعمل build جديد للتطبيق بـ
        <code className="mx-1 px-1.5 py-0.5 bg-white/5 rounded">flutter build apk --release --build-name=1.1.0 --build-number=2</code>
        <br />
        2) ارفع ملف الـ APK هنا أو حط رابط مباشر.
        <br />
        3) اضغط «نشر التحديث» — أول ما أي مستخدم يفتح التطبيق هتظهر له نافذة التحديث مع شريط تقدم وتثبيت مباشر.
      </div>
    </div>
  );
}
