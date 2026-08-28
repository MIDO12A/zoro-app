import { useEffect, useState } from 'react';
import { AppConfig } from '../types';
import { getAppConfig, updateAppConfig } from '../lib/db';
import { uploadToCloudinary } from '../lib/storage';
import { to6Hex } from '../lib/colors';
import { Save, Upload, RotateCcw } from 'lucide-react';

export default function ProfileCustomizePage() {
  const [config, setConfig] = useState<AppConfig>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    getAppConfig().then(data => { if (data) setConfig(data); setLoading(false); });
  }, []);

  const handleSave = async () => {
    setSaving(true);
    await updateAppConfig(config);
    setSaving(false);
    alert('Saved successfully! Restart the app to see changes.');
  };

  const handleUpload = async (field: string, e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const url = await uploadToCloudinary(file, 'profile');
    setConfig(p => ({ ...p, [field]: url }));
  };

  const resetAll = () => {
    if (!confirm('Are you sure you want to reset profile settings to default?')) return;
    const updates = {
      profileBgType: 'solid',
      profileSolidColor: '#03030A',
      profileGradientColors: ['#1E1E2C', '#03030A'],
      profileBackgroundImage: '',
      profileShowSignature: true,
      profileShowId: true,
      profileShowLevel: true,
      buttonStyle: 'modern'
    };
    setConfig(p => ({ ...p, ...updates }));
  };

  if (loading) return <div className="text-slate-500 text-xs">Loading...</div>;

  const bgType = (config as any).profileBgType || 'solid';
  const gradientColors = (config as any).profileGradientColors || ['#1E1E2C', '#03030A'];

  return (
    <div className="space-y-6 max-w-3xl">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-white text-lg font-semibold">User Profile Customization</h2>
          <p className="text-slate-500 text-xs mt-0.5">Customize the appearance of the user profile screen</p>
        </div>
        <div className="flex gap-2">
          <button onClick={resetAll} className="flex items-center gap-2 bg-[#1A1A24] hover:bg-[#2A2A3A] text-slate-300 text-xs font-medium px-4 py-2 rounded-lg transition-all">
            <RotateCcw className="w-4 h-4" /> Reset
          </button>
          <button onClick={handleSave} disabled={saving} className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-500 disabled:bg-indigo-800 text-white text-xs font-medium px-4 py-2 rounded-lg transition-all">
            <Save className="w-4 h-4" />
            {saving ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      </div>

      {/* Header Background Section */}
      <div className="bg-[#141417] rounded-2xl border border-white/5 p-6 space-y-4">
        <h3 className="text-white text-sm font-semibold">Profile Background</h3>
        
        <div>
          <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1.5">Background Type</label>
          <select 
            value={bgType} 
            onChange={e => setConfig(p => ({ ...p, profileBgType: e.target.value }))}
            className="w-full bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white"
          >
            <option value="solid">Solid Color (لون ثابت)</option>
            <option value="gradient">Gradient (تدرج لوني)</option>
            <option value="image">Image (صورة)</option>
          </select>
        </div>

        {bgType === 'solid' && (
          <div>
            <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1.5">Solid Color</label>
            <div className="flex gap-2 items-center">
              <input type="color" value={to6Hex(((config as any).profileSolidColor as string) || '#03030A')} onChange={e => setConfig(p => ({ ...p, profileSolidColor: e.target.value }))} className="w-10 h-10 rounded cursor-pointer bg-transparent border border-white/10 shrink-0" />
              <input type="text" value={(config as any).profileSolidColor || '#03030A'} onChange={e => setConfig(p => ({ ...p, profileSolidColor: e.target.value }))} className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white font-mono" />
            </div>
          </div>
        )}

        {bgType === 'gradient' && (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1.5">Gradient Start Color</label>
              <div className="flex gap-2 items-center">
                <input type="color" value={to6Hex(gradientColors[0])} onChange={e => {
                  const newColors = [...gradientColors];
                  newColors[0] = e.target.value;
                  setConfig(p => ({ ...p, profileGradientColors: newColors }));
                }} className="w-10 h-10 rounded cursor-pointer bg-transparent border border-white/10 shrink-0" />
                <input type="text" value={gradientColors[0]} onChange={e => {
                  const newColors = [...gradientColors];
                  newColors[0] = e.target.value;
                  setConfig(p => ({ ...p, profileGradientColors: newColors }));
                }} className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white font-mono" />
              </div>
            </div>
            <div>
              <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1.5">Gradient End Color</label>
              <div className="flex gap-2 items-center">
                <input type="color" value={to6Hex(gradientColors[1] || '#000000')} onChange={e => {
                  const newColors = [...gradientColors];
                  newColors[1] = e.target.value;
                  setConfig(p => ({ ...p, profileGradientColors: newColors }));
                }} className="w-10 h-10 rounded cursor-pointer bg-transparent border border-white/10 shrink-0" />
                <input type="text" value={gradientColors[1] || '#000000'} onChange={e => {
                  const newColors = [...gradientColors];
                  newColors[1] = e.target.value;
                  setConfig(p => ({ ...p, profileGradientColors: newColors }));
                }} className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white font-mono" />
              </div>
            </div>
          </div>
        )}

        {bgType === 'image' && (
          <div>
            <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1.5">Background Image URL</label>
            <div className="flex items-center gap-4">
              {(config as any).profileBackgroundImage ? (
                <div className="relative">
                  <img src={(config as any).profileBackgroundImage} className="w-32 h-20 object-cover rounded-lg border border-white/5" />
                  <button onClick={() => setConfig(p => ({ ...p, profileBackgroundImage: '' }))} className="absolute -top-2 -right-2 w-5 h-5 rounded-full bg-rose-500 text-white text-[10px]">×</button>
                </div>
              ) : (
                <label className="w-32 h-20 rounded-lg border-2 border-dashed border-white/10 flex flex-col items-center justify-center cursor-pointer hover:border-indigo-500/50 transition-all">
                  <Upload className="w-5 h-5 text-slate-500 mb-1" />
                  <span className="text-[9px] text-slate-600">Upload</span>
                  <input type="file" accept="image/*" onChange={(e) => handleUpload('profileBackgroundImage', e)} className="hidden" />
                </label>
              )}
            </div>
            <input type="text" value={(config as any).profileBackgroundImage || ''} onChange={e => setConfig(p => ({ ...p, profileBackgroundImage: e.target.value }))} placeholder="Or paste image URL..." className="w-full mt-2 bg-[#161618] border border-white/10 rounded-lg py-1.5 px-2 text-xs text-white font-mono" />
          </div>
        )}
      </div>

      {/* Toggles Visibility */}
      <div className="bg-[#141417] rounded-2xl border border-white/5 p-6 space-y-4">
        <h3 className="text-white text-sm font-semibold">Components Visibility (إخفاء وإظهار)</h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {[
            { key: 'profileShowSignature', label: 'Show Signature (التوقيع)' },
            { key: 'profileShowId', label: 'Show User ID (رقم الحساب)' },
            { key: 'profileShowLevel', label: 'Show Level Badge (مستوى الحساب)' },
          ].map(({ key, label }) => (
            <label key={key} className="flex items-center justify-between p-3 rounded-lg border border-white/5 bg-[#161618] cursor-pointer hover:bg-white/[0.02]">
              <span className="text-xs text-slate-300">{label}</span>
              <input 
                type="checkbox" 
                checked={(config as any)[key] !== false} 
                onChange={e => setConfig(p => ({ ...p, [key]: e.target.checked }))} 
                className="w-4 h-4 rounded border-white/20 bg-transparent text-indigo-500 focus:ring-offset-0 focus:ring-0 cursor-pointer" 
              />
            </label>
          ))}
        </div>
      </div>

      {/* Button Styles */}
      <div className="bg-[#141417] rounded-2xl border border-white/5 p-6 space-y-4">
        <h3 className="text-white text-sm font-semibold">Action Buttons Style</h3>
        
        <div>
          <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1.5">Button Style</label>
          <select 
            value={(config as any).buttonStyle || 'modern'} 
            onChange={e => setConfig(p => ({ ...p, buttonStyle: e.target.value }))}
            className="w-full bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white"
          >
            <option value="modern">Modern (عصري - زوايا مستديرة)</option>
            <option value="classic">Classic (كلاسيكي - أزرار مربعة)</option>
          </select>
        </div>
      </div>

    </div>
  );
}
