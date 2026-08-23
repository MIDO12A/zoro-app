import { useEffect, useState, useContext } from 'react';
import { StoreItemModel } from '../types';
import { getStoreItems, deleteStoreItem, updateStoreItem, addStoreItem } from '../lib/db';
import { uploadStoreItem } from '../lib/storage';
import DataTable from '../components/DataTable';
import ImageUpload from '../components/ImageUpload';
import { Coins, Plus, Save, X } from 'lucide-react';
import { I18nContext } from '../lib/i18n';

const categories = ['frame', 'bubble', 'entrance', 'car', 'cover'] as const;
const svgaCategories = new Set(['entrance', 'car', 'cover']);

export default function StorePage() {
  const [items, setItems] = useState<StoreItemModel[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<StoreItemModel | null>(null);
  const [showAdd, setShowAdd] = useState(false);
  const [form, setForm] = useState({ name: '', category: 'frame' as StoreItemModel['category'], iconAsset: '', price: 0, svgaAsset: '', videoAsset: '', isPremium: false, nameKey: '', photoKey: '', defaultImage: '' });
  const { t } = useContext(I18nContext);

  const load = async () => { const d = await getStoreItems(); setItems(d); setLoading(false); };
  useEffect(() => { load(); }, []);

  const resetForm = () => setForm({ name: '', category: 'frame', iconAsset: '', price: 0, svgaAsset: '', videoAsset: '', isPremium: false, nameKey: '', photoKey: '', defaultImage: '' });

  const handleEdit = (item: StoreItemModel) => {
    setEditing(item);
    setForm({ name: item.name, category: item.category, iconAsset: item.iconAsset, price: item.price, svgaAsset: item.svgaAsset || '', videoAsset: item.videoAsset || '', isPremium: item.isPremium, nameKey: item.nameKey || '', photoKey: item.photoKey || '', defaultImage: item.defaultImage || '' });
    setShowAdd(false);
  };

  const handleSave = async () => {
    if (!editing) return;
    await updateStoreItem(editing.itemId, { ...form, svgaAsset: form.svgaAsset || null, videoAsset: form.videoAsset || null, nameKey: form.nameKey || null, photoKey: form.photoKey || null, defaultImage: form.defaultImage || null });
    setEditing(null); resetForm(); load();
  };
  const handleDelete = async (item: StoreItemModel) => { if (confirm(`Delete ${item.name}?`)) { await deleteStoreItem(item.itemId); load(); } };
  const handleAdd = async () => {
    const id = `store_${Date.now()}`;
    await addStoreItem(id, { ...form, itemId: id, svgaAsset: form.svgaAsset || null, videoAsset: form.videoAsset || null, nameKey: form.nameKey || null, photoKey: form.photoKey || null, defaultImage: form.defaultImage || null });
    setShowAdd(false); resetForm(); load();
  };
  const updateField = (f: string, v: unknown) => setForm(p => ({ ...p, [f]: v }));
  const showDynamicKeys = svgaCategories.has(form.category);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-white text-lg font-semibold">{t('store.management')}</h2>
          <p className="text-slate-500 text-xs mt-0.5">{items.length} {t('store.count')}</p>
        </div>
        <button onClick={() => { setShowAdd(!showAdd); setEditing(null); resetForm(); }} className="px-3 py-1.5 bg-indigo-600 hover:bg-indigo-700 text-xs text-white font-semibold rounded-lg flex items-center gap-1">
          <Plus className="w-3.5 h-3.5" /> {showAdd ? t('cancel') : t('store.add')}
        </button>
      </div>

      {(editing || showAdd) && (
        <div className="bg-[#141417] rounded-2xl border border-indigo-500/20 p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-white font-semibold text-sm">{editing ? `${t('store.edit')}: ${editing.name}` : t('store.new')}</h3>
            <button onClick={() => { setEditing(null); setShowAdd(false); }} className="text-slate-400 hover:text-white"><X className="w-4 h-4" /></button>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <ImageUpload
              currentUrl={form.iconAsset}
              onUpload={file => uploadStoreItem(file, editing?.itemId || `new_${Date.now()}`)}
              onUrlChange={url => updateField('iconAsset', url)}
              label={t('upload')}
            />
            <div>
              <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1">{t('gift.name')}</label>
              <input type="text" value={form.name} onChange={e => updateField('name', e.target.value)} className="w-full bg-[#161618] border border-white/10 rounded-lg py-1.5 px-2 text-xs text-white" />
            </div>
            <div>
              <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1">{t('store.category')}</label>
              <select value={form.category} onChange={e => updateField('category', e.target.value)} className="w-full bg-[#161618] border border-white/10 rounded-lg py-1.5 px-2 text-xs text-white">
                {categories.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1">{t('store.price')}</label>
              <input type="number" value={form.price} onChange={e => updateField('price', Number(e.target.value))} className="w-full bg-[#161618] border border-white/10 rounded-lg py-1.5 px-2 text-xs text-white" />
            </div>
            <div className="col-span-2">
              <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1">SVGA Asset URL</label>
              <ImageUpload
                currentUrl={form.svgaAsset}
                onUpload={file => uploadStoreItem(file, editing?.itemId || `new_${Date.now()}`)}
                onUrlChange={url => updateField('svgaAsset', url)}
                label="Animation"
                accept=".svga,.json,.zip"
              />
            </div>
            <div className="col-span-2">
              <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1">Video Asset URL (MP4/VAP)</label>
              <ImageUpload
                currentUrl={form.videoAsset}
                onUpload={file => uploadStoreItem(file, editing?.itemId || `new_${Date.now()}`)}
                onUrlChange={url => updateField('videoAsset', url)}
                label="Video"
                accept=".mp4,.vap"
              />
            </div>
            {showDynamicKeys && (
              <>
                <div>
                  <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1">Name Key</label>
                  <input type="text" value={form.nameKey} onChange={e => updateField('nameKey', e.target.value)} placeholder="e.g. txt_name" className="w-full bg-[#161618] border border-white/10 rounded-lg py-1.5 px-2 text-xs text-white" />
                </div>
                <div>
                  <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1">Photo Key</label>
                  <input type="text" value={form.photoKey} onChange={e => updateField('photoKey', e.target.value)} placeholder="e.g. img_avatar" className="w-full bg-[#161618] border border-white/10 rounded-lg py-1.5 px-2 text-xs text-white" />
                </div>
                <div className="col-span-2">
                  <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1">Default Image URL</label>
                  <ImageUpload
                    currentUrl={form.defaultImage}
                    onUpload={file => uploadStoreItem(file, `default_${editing?.itemId || `new_${Date.now()}`}`)}
                    onUrlChange={url => updateField('defaultImage', url)}
                    label="Default Image"
                    accept="image/*"
                  />
                </div>
              </>
            )}
          </div>
          <div className="flex items-center gap-4">
            <label className="flex items-center gap-1.5 text-xs text-slate-400">
              <input type="checkbox" checked={form.isPremium} onChange={e => updateField('isPremium', e.target.checked)} className="accent-indigo-500" />
              {t('store.premium')}
            </label>
          </div>
          <div className="flex gap-2">
            <button onClick={editing ? handleSave : handleAdd} className="px-4 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-xs text-white font-semibold rounded-lg flex items-center gap-1">
              <Save className="w-3 h-3" /> {editing ? t('save') : t('store.add')}
            </button>
          </div>
        </div>
      )}

      <DataTable
        loading={loading}
        columns={[
          { key: 'iconAsset', label: '', width: '40px', render: i => i.iconAsset ? <img src={i.iconAsset} className="w-6 h-6 object-contain" /> : <div className="w-6 h-6 rounded bg-slate-800" /> },
          { key: 'name', label: t('gift.name'), sortable: true },
          { key: 'category', label: t('store.category'), sortable: true, render: i => <span className="text-indigo-400 text-[10px] uppercase">{i.category}</span> },
          { key: 'price', label: t('store.price'), sortable: true, render: i => <span className="flex items-center gap-1 text-amber-400"><Coins className="w-3 h-3" />{i.price}</span> },
          { key: 'isPremium', label: t('store.premium'), render: i => i.isPremium ? <span className="text-rose-400">✓</span> : '-' },
        ]}
        data={items}
        searchKeys={['name', 'category']}
        onEdit={handleEdit}
        onDelete={handleDelete}
      />
    </div>
  );
}
