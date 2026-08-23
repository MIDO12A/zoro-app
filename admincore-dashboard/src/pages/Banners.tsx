import { useEffect, useState } from 'react';
import { BannerConfig } from '../types';
import { supabase } from '../lib/supabase';
import { uploadBanner } from '../lib/storage';
import ImageUpload from '../components/ImageUpload';
import { Plus, Save, X, Trash2 } from 'lucide-react';

export default function BannersPage() {
  const [banners, setBanners] = useState<BannerConfig[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<BannerConfig | null>(null);
  const [showAdd, setShowAdd] = useState(false);
  const [form, setForm] = useState({ imageUrl: '', linkUrl: '', title: '', sortOrder: 0, active: true });

  const load = async () => {
    const { data } = await supabase.from('banners').select('*').order('sort_order');
    const toCamel = (r: Record<string, unknown>): Record<string, unknown> => {
      const c: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(r)) {
        c[k.replace(/_([a-z])/g, (_, ch) => ch.toUpperCase())] = v;
      }
      return c;
    };
    const list = (data ?? []).map(r => toCamel(r) as unknown as BannerConfig);
    list.sort((a, b) => a.sortOrder - b.sortOrder);
    setBanners(list);
    setLoading(false);
  };
  useEffect(() => { load(); }, []);

  useEffect(() => {
    const sub = supabase.channel('banners').on('postgres_changes',
      { event: '*', schema: 'public', table: 'banners' }, () => { load(); }
    ).subscribe();
    return () => { supabase.removeChannel(sub); };
  }, []);

  const resetForm = () => setForm({ imageUrl: '', linkUrl: '', title: '', sortOrder: banners.length, active: true });

  const handleEdit = (b: BannerConfig) => {
    setEditing(b);
    setForm({ imageUrl: b.imageUrl, linkUrl: b.linkUrl || '', title: b.title || '', sortOrder: b.sortOrder, active: b.active });
    setShowAdd(false);
  };

  const handleSave = async () => {
    if (!editing) return;
    await supabase.from('banners').update({
      image_url: form.imageUrl,
      link_url: form.linkUrl,
      title: form.title,
      sort_order: form.sortOrder,
      active: form.active,
    }).eq('id', editing.id);
    setEditing(null); resetForm();
    load();
  };

  const handleDelete = async (b: BannerConfig) => {
    if (confirm(`Delete banner "${b.title || b.id}"?`)) {
      await supabase.from('banners').delete().eq('id', b.id);
      load();
    }
  };

  const handleAdd = async () => {
    const id = `banner_${Date.now()}`;
    await supabase.from('banners').insert({
      id,
      image_url: form.imageUrl,
      link_url: form.linkUrl,
      title: form.title,
      sort_order: form.sortOrder,
      active: form.active,
    });
    setShowAdd(false); resetForm();
    load();
  };

  const updateForm = (f: string, v: unknown) => setForm(p => ({ ...p, [f]: v }));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-white text-lg font-semibold">Banners / Slider Management</h2>
          <p className="text-slate-500 text-xs mt-0.5">{banners.length} banners</p>
        </div>
        <button onClick={() => { setShowAdd(!showAdd); setEditing(null); resetForm(); }} className="px-3 py-1.5 bg-indigo-600 hover:bg-indigo-700 text-xs text-white font-semibold rounded-lg flex items-center gap-1">
          <Plus className="w-3.5 h-3.5" /> {showAdd ? 'Cancel' : 'Add Banner'}
        </button>
      </div>

      {(editing || showAdd) && (
        <div className="bg-[#141417] rounded-2xl border border-indigo-500/20 p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-white font-semibold text-sm">{editing ? `Editing: ${editing.title || editing.id}` : 'New Banner'}</h3>
            <button onClick={() => { setEditing(null); setShowAdd(false); }} className="text-slate-400 hover:text-white"><X className="w-4 h-4" /></button>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <ImageUpload
              currentUrl={form.imageUrl}
              onUpload={file => uploadBanner(file, editing?.id || `new_${Date.now()}`)}
              onUrlChange={url => updateForm('imageUrl', url)}
              label="Banner Image"
            />
            <div className="space-y-3">
              <div>
                <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1">Title</label>
                <input type="text" value={form.title} onChange={e => updateForm('title', e.target.value)} className="w-full bg-[#161618] border border-white/10 rounded-lg py-1.5 px-2 text-xs text-white" />
              </div>
              <div>
                <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1">Link URL</label>
                <input type="text" value={form.linkUrl} onChange={e => updateForm('linkUrl', e.target.value)} className="w-full bg-[#161618] border border-white/10 rounded-lg py-1.5 px-2 text-xs text-white" />
              </div>
              <div className="flex gap-4">
                <div>
                  <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1">Sort Order</label>
                  <input type="number" value={form.sortOrder} onChange={e => updateForm('sortOrder', Number(e.target.value))} className="w-20 bg-[#161618] border border-white/10 rounded-lg py-1.5 px-2 text-xs text-white" />
                </div>
                <div className="flex items-end">
                  <label className="flex items-center gap-1.5 text-xs text-slate-400 pb-1.5">
                    <input type="checkbox" checked={form.active} onChange={e => updateForm('active', e.target.checked)} className="accent-indigo-500" />
                    Active
                  </label>
                </div>
              </div>
            </div>
          </div>
          {form.imageUrl && (
            <img src={form.imageUrl} className="w-full h-32 object-cover rounded-lg border border-white/5" />
          )}
          <div className="flex gap-2">
            <button onClick={editing ? handleSave : handleAdd} className="px-4 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-xs text-white font-semibold rounded-lg flex items-center gap-1">
              <Save className="w-3 h-3" /> {editing ? 'Save Changes' : 'Add Banner'}
            </button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="text-center py-12 text-slate-500 text-xs">Loading...</div>
      ) : banners.length === 0 ? (
        <div className="text-center py-12 text-slate-500 text-xs">No banners yet. Click "Add Banner" to create one.</div>
      ) : (
        <div className="space-y-3">
          {banners.map(b => (
            <div key={b.id} className="bg-[#141417] rounded-2xl border border-white/5 p-4 flex items-center gap-4 hover:border-white/10 transition-colors">
              {b.imageUrl ? (
                <img src={b.imageUrl} className="w-24 h-14 object-cover rounded-lg border border-white/5" />
              ) : (
                <div className="w-24 h-14 rounded-lg bg-slate-800 flex items-center justify-center text-[10px] text-slate-600">No Image</div>
              )}
              <div className="flex-1 min-w-0">
                <div className="text-white text-xs font-medium truncate">{b.title || 'Untitled'}</div>
                <div className="text-[10px] text-slate-500 truncate">{b.linkUrl || 'No link'}</div>
                <div className="flex items-center gap-2 mt-1">
                  <span className={`text-[9px] px-1.5 py-0.5 rounded-full ${b.active ? 'bg-emerald-500/10 text-emerald-400' : 'bg-slate-500/10 text-slate-500'}`}>{b.active ? 'Active' : 'Inactive'}</span>
                  <span className="text-[9px] text-slate-600">Order: {b.sortOrder}</span>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <button onClick={() => handleEdit(b)} className="text-[10px] text-indigo-400 hover:text-indigo-300 font-semibold">Edit</button>
                <button onClick={() => handleDelete(b)} className="text-[10px] text-rose-400 hover:text-rose-300 font-semibold"><Trash2 className="w-3 h-3" /></button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
