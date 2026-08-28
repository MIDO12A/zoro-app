import { useEffect, useState } from 'react';
import { AppAssetRecord } from '../types';
import { getAppAssets, upsertAppAsset, deleteAppAsset } from '../lib/db';
import { uploadAppAsset } from '../lib/storage';
import { Upload, Smile } from 'lucide-react';

export default function Emojis() {
  const [assets, setAssets] = useState<AppAssetRecord[]>([]);
  const [uploading, setUploading] = useState(false);
  const [loading, setLoading] = useState(true);

  const loadAssets = async () => {
    try {
      setLoading(true);
      const res = await getAppAssets();
      setAssets((res.data || []).filter(a => a.category === 'emoji'));
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadAssets();
  }, []);

  const handleUpload = async () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*,.svga,.mp4,.gif,.vap,.json,.webp';
    input.onchange = async () => {
      const file = input.files?.[0];
      if (!file) return;
      setUploading(true);
      try {
        const key = `emoji_${Date.now()}`;
        const url = await uploadAppAsset(file, key);
        const record: AppAssetRecord = {
          id: crypto.randomUUID(),
          key: key,
          name: file.name,
          type: file.name.endsWith('.svga') ? 'svga' : file.name.endsWith('.vap') ? 'vap' : file.name.endsWith('.json') ? 'lottie' : 'image',
          category: 'emoji',
          subcategory: '',
          localPath: '',
          remoteUrl: url,
          defaultValue: '',
          mimeType: file.type || 'application/octet-stream',
          fileSize: file.size,
          width: null, height: null, sortOrder: 0, isActive: true,
          createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
        };
        await upsertAppAsset(record);
        await loadAssets();
      } catch (err) { alert('فشل الرفع: ' + (err as Error).message); }
      setUploading(false);
    };
    input.click();
  };

  const handleDelete = async (id: string) => {
    if (!confirm('هل تريد فعلاً حذف هذا الإيموجي؟')) return;
    try {
      await deleteAppAsset(id);
      await loadAssets();
    } catch {}
  };

  return (
    <div className="space-y-6" dir="rtl">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-white text-lg font-semibold flex items-center gap-2">
            <Smile className="w-5 h-5 text-yellow-400" />
            الإيموجيات المتحركة
          </h2>
          <p className="text-slate-500 text-xs mt-0.5">إدارة وإضافة الإيموجيات التي تظهر داخل المحادثات والغرف الصوتية.</p>
        </div>
        <button onClick={handleUpload} disabled={uploading} className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white text-xs font-bold rounded-lg flex items-center gap-2 transition-colors">
          <Upload className="w-4 h-4" /> {uploading ? 'جاري الرفع...' : 'إضافة إيموجي'}
        </button>
      </div>

      {loading ? (
        <div className="text-center py-10 text-slate-500 text-sm">جاري التحميل...</div>
      ) : assets.length === 0 ? (
        <div className="text-center py-16 bg-[#111113] rounded-xl border border-dashed border-white/10 text-slate-500 text-sm">
          لا يوجد إيموجيات حالياً. اضغط على زر الإضافة للبدء.
        </div>
      ) : (
        <div className="grid grid-cols-3 sm:grid-cols-5 md:grid-cols-6 lg:grid-cols-8 gap-4">
          {assets.map(a => (
            <div key={a.id} className="bg-[#1a1a1e] rounded-xl border border-white/5 overflow-hidden group">
              <div className="relative w-full aspect-square bg-black/40 flex items-center justify-center p-2">
                <img src={a.remoteUrl} className="max-w-full max-h-full object-contain" />
              </div>
              <div className="flex justify-between items-center p-2 bg-[#202025]">
                <span className="text-[10px] text-slate-400 truncate w-2/3" title={a.name}>{a.name}</span>
                <button onClick={() => handleDelete(a.id)} className="text-xs text-rose-500 hover:text-rose-400 hover:bg-rose-500/10 p-1.5 rounded transition-colors">🗑</button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
