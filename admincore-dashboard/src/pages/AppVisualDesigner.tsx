import { useEffect, useState, useContext } from 'react';
import { I18nContext } from '../lib/i18n';
import { getAppConfig, updateAppConfig } from '../lib/db';
import { uploadAppAsset } from '../lib/storage';
import { Save, RotateCcw, Upload, Phone, ChevronRight, MessageSquare, User, Info, Bell, Search, Compass, Send, Copy, Plus } from 'lucide-react';
import { to6Hex } from '../lib/colors';

interface ScreenVisuals {
  agency: Record<string, string>;
  badges: Record<string, string>;
  necklaces: Record<string, string>;
  rank: Record<string, string>;
  checkbox: Record<string, string>;
  store: Record<string, string>;
  backpack: Record<string, string>;
  wallet: Record<string, string>;
  level: Record<string, string>;
  cp: Record<string, string>;
  signin: Record<string, string>;
  room: Record<string, string>;
  discover: Record<string, string>;
  message: Record<string, string>;
  profile: Record<string, string>;
  chat: Record<string, string>;
  userProfile: Record<string, string>;
  eventInfo: Record<string, string>;
  notifications: Record<string, string>;
}

const defaultVisuals: ScreenVisuals = {
  agency: {}, badges: {}, necklaces: {}, rank: {}, checkbox: {}, store: {}, backpack: {}, wallet: {}, level: {}, cp: {}, signin: {}, room: {},
  discover: {
    backgroundImage: '',
    backgroundColor: '#ffffff',
    textColor: '#16151a',
    subTextColor: '#9ba1b6',
    cardBgColor: '#f7f7f8',
  },
  message: {
    backgroundImage: '',
    backgroundColor: '#ffffff',
    textColor: '#16151a',
    subTextColor: '#9ba1b6',
    cardBgColor: '#f7f7f8',
  },
  profile: {
    backgroundImage: '',
    backgroundColor: '#f6f7f9',
    textColor: '#000000',
    subTextColor: '#888888',
    cardBgColor: '#ffffff',
  },
  chat: {
    backgroundImage: '',
    backgroundColor: '#f2f3f5',
    textColor: '#000000',
    bubbleSelfBgColor: '#ffe082',
    bubbleOtherBgColor: '#ffffff',
  },
  userProfile: {
    backgroundImage: '',
    backgroundColor: '#16151A',
    textColor: '#ffffff',
    subTextColor: '#9BA1B6',
    buttonColor: '#FFE082',
  },
  eventInfo: {
    backgroundImage: '',
    backgroundColor: '#ffffff',
    textColor: '#000000',
    subTextColor: '#888888',
  },
  notifications: {
    backgroundImage: '',
    backgroundColor: '#211211',
    textColor: '#ffffff',
    subTextColor: '#b3b3b3',
    cardBgColor: '#301c1a',
  },
};

const screens = [
  { id: 'discover', labelAr: '🔍 شاشة الاستكشاف', labelEn: '🔍 Discover Screen' },
  { id: 'message', labelAr: '💬 شاشة الرسائل', labelEn: '💬 Messages Screen' },
  { id: 'profile', labelAr: '👤 شاشة حسابي (أنا)', labelEn: '👤 Profile Screen' },
  { id: 'chat', labelAr: '✉️ شاشة المحادثة الخاصة', labelEn: '✉️ Private Chat' },
  { id: 'userProfile', labelAr: '🏷️ بطاقة المستخدم المصغرة', labelEn: '🏷️ User Card' },
  { id: 'eventInfo', labelAr: '📅 تفاصيل الحدث من الداخل', labelEn: '📅 Event Info' },
  { id: 'notifications', labelAr: '🔔 إشعارات النظام', labelEn: '🔔 System Notifications' },
] as const;

type ScreenId = typeof screens[number]['id'];

export default function AppVisualDesigner() {
  const { lang } = useContext(I18nContext);
  const [activeTab, setActiveTab] = useState<ScreenId>('discover');
  const [visuals, setVisuals] = useState<ScreenVisuals>(defaultVisuals);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');

  useEffect(() => {
    (async () => {
      try {
        const cfg = await getAppConfig();
        const stored = cfg?.screenVisuals;
        if (stored && typeof stored === 'object') {
          const merged: ScreenVisuals = { ...defaultVisuals };
          for (const s of Object.keys(defaultVisuals) as Array<keyof ScreenVisuals>) {
            if (stored[s] && typeof stored[s] === 'object') {
              merged[s] = { ...defaultVisuals[s], ...stored[s] };
            }
          }
          setVisuals(merged);
        }
      } catch (e) { console.warn(e); }
      setLoading(false);
    })();
  }, []);

  const showMsg = (text: string) => { setMsg(text); setTimeout(() => setMsg(''), 3000); };

  const updateField = (screen: ScreenId, field: string, value: string) => {
    setVisuals(prev => ({
      ...prev,
      [screen]: { ...prev[screen], [field]: value },
    }));
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      const cfg = await getAppConfig();
      const stored = cfg?.screenVisuals || {};
      const clean = { ...stored, ...visuals };
      await updateAppConfig({ screenVisuals: clean } as any);
      showMsg(lang === 'ar' ? 'تم حفظ التعديلات بنجاح!' : 'Changes saved successfully!');
    } catch (e) {
      showMsg(lang === 'ar' ? 'فشل حفظ التعديلات' : 'Save failed');
      console.warn(e);
    }
    setSaving(false);
  };

  const handleReset = () => {
    if (confirm(lang === 'ar' ? 'إعادة تعيين إعدادات هذه الشاشة؟' : 'Reset this screen\'s visuals?')) {
      setVisuals(prev => ({
        ...prev,
        [activeTab]: { ...defaultVisuals[activeTab] },
      }));
    }
  };

  const handleImageUpload = async (file: File, screen: ScreenId, field: string) => {
    try {
      const path = `screen_visuals/${screen}_${field}_${Date.now()}`;
      const url = await uploadAppAsset(file, path);
      if (url) updateField(screen, field, url);
    } catch (e) {
      showMsg(lang === 'ar' ? 'فشل رفع الصورة' : 'Upload failed');
    }
  };

  if (loading) return <div className="text-slate-400 text-sm p-6">Loading Visual Designer...</div>;

  const currentConfig = visuals[activeTab] || {};

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-white text-lg font-semibold flex items-center gap-2">
            <Phone className="w-5 h-5 text-indigo-400" />
            {lang === 'ar' ? 'مصمم المظهر البصري للتطبيق' : 'App Visual Designer'}
          </h2>
          <p className="text-slate-400 text-xs mt-1">
            {lang === 'ar'
              ? 'صمم خلفيات وألوان شاشات التطبيق مباشرة وشاهد النتيجة فوراً على محاكي الهاتف.'
              : 'Customize background images and colors of core app screens and view live updates on the mock phone.'}
          </p>
        </div>
        <div className="flex gap-2">
          <button onClick={handleReset} className="px-3 py-1.5 bg-rose-600/20 hover:bg-rose-600/30 text-rose-400 text-xs font-semibold rounded-lg flex items-center gap-1">
            <RotateCcw className="w-3.5 h-3.5" /> {lang === 'ar' ? 'إعادة تعيين' : 'Reset'}
          </button>
          <button onClick={handleSave} disabled={saving} className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-xs text-white font-semibold rounded-lg flex items-center gap-1 shadow-lg shadow-emerald-900/20">
            <Save className="w-3.5 h-3.5" /> {saving ? (lang === 'ar' ? 'جاري الحفظ...' : 'Saving...') : (lang === 'ar' ? 'حفظ المظهر' : 'Save Theme')}
          </button>
        </div>
      </div>

      {msg && <div className="bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-xs px-4 py-2 rounded-lg">{msg}</div>}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        {/* Left Side: Mock Phone (4 cols) */}
        <div className="lg:col-span-5 flex justify-center">
          <div className="w-[320px] h-[640px] rounded-[40px] border-[10px] border-slate-800 bg-[#09090b] relative overflow-hidden shadow-2xl flex flex-col">
            {/* Notch */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-32 h-6 bg-slate-800 rounded-b-2xl z-50 flex items-center justify-center">
              <div className="w-3 h-3 rounded-full bg-slate-900 border border-slate-700/50" />
            </div>

            {/* Live screen mockup container */}
            <div
              className="flex-1 relative overflow-y-auto pt-8 flex flex-col"
              style={{
                backgroundColor: currentConfig.backgroundColor || '#111',
                backgroundImage: currentConfig.backgroundImage ? `url(${currentConfig.backgroundImage})` : 'none',
                backgroundSize: 'cover',
                backgroundPosition: 'center',
                color: currentConfig.textColor || '#fff',
              }}
            >
              {/* Discover Screen Mockup */}
              {activeTab === 'discover' && (
                <div className="flex-1 flex flex-col px-3 py-2 space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="font-bold text-sm" style={{ color: currentConfig.textColor }}>
                      {lang === 'ar' ? 'الاستكشاف' : 'Discover'}
                    </span>
                    <Search className="w-4 h-4" style={{ color: currentConfig.textColor }} />
                  </div>
                  {/* Category Tabs */}
                  <div className="flex gap-2">
                    {['دردشة', 'ألعاب', 'حفلة'].map((tab, idx) => (
                      <span
                        key={idx}
                        className="px-3 py-1 rounded-full text-[10px] font-medium"
                        style={{
                          backgroundColor: idx === 0 ? (currentConfig.textColor + '15') : 'transparent',
                          color: idx === 0 ? currentConfig.textColor : currentConfig.subTextColor,
                          border: `1px solid ${idx === 0 ? currentConfig.textColor : 'transparent'}`,
                        }}
                      >
                        {tab}
                      </span>
                    ))}
                  </div>
                  {/* Mock Banners */}
                  <div className="h-24 rounded-xl bg-gradient-to-r from-purple-500/20 to-indigo-500/20 border border-white/5 flex items-center justify-center">
                    <span className="text-[10px]" style={{ color: currentConfig.subTextColor }}>🔥 Banner Carousel</span>
                  </div>
                  {/* Mock Rooms Grid */}
                  <div className="grid grid-cols-2 gap-2">
                    {[1, 2, 3, 4].map((id) => (
                      <div
                        key={id}
                        className="rounded-xl p-2.5 flex flex-col space-y-2 border border-white/5"
                        style={{ backgroundColor: currentConfig.cardBgColor || 'rgba(255,255,255,0.05)' }}
                      >
                        <div className="w-8 h-8 rounded-lg bg-indigo-600/40 flex items-center justify-center text-xs">🎙</div>
                        <span className="text-[10px] font-semibold truncate" style={{ color: currentConfig.textColor }}>
                          {lang === 'ar' ? `غرفة رقم ${id}` : `Room #${id}`}
                        </span>
                        <span className="text-[8px]" style={{ color: currentConfig.subTextColor }}>
                          👤 2.4k online
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Messages Screen Mockup */}
              {activeTab === 'message' && (
                <div className="flex-1 flex flex-col px-3 py-2 space-y-4">
                  <span className="font-bold text-sm" style={{ color: currentConfig.textColor }}>
                    {lang === 'ar' ? 'الرسائل' : 'Messages'}
                  </span>
                  {/* Top info cards */}
                  <div className="flex gap-2">
                    <div
                      className="flex-1 p-2 rounded-xl flex items-center gap-2 border border-white/5"
                      style={{ backgroundColor: currentConfig.cardBgColor || 'rgba(255,255,255,0.05)' }}
                    >
                      <div className="w-6 h-6 rounded-lg bg-yellow-500/20 flex items-center justify-center text-xs">📅</div>
                      <div className="flex flex-col text-[8px]">
                        <span className="font-bold" style={{ color: currentConfig.textColor }}>{lang === 'ar' ? 'الحدث' : 'Event'}</span>
                        <span style={{ color: currentConfig.subTextColor }}>2 updates</span>
                      </div>
                    </div>
                    <div
                      className="flex-1 p-2 rounded-xl flex items-center gap-2 border border-white/5"
                      style={{ backgroundColor: currentConfig.cardBgColor || 'rgba(255,255,255,0.05)' }}
                    >
                      <div className="w-6 h-6 rounded-lg bg-indigo-500/20 flex items-center justify-center text-xs">🔔</div>
                      <div className="flex flex-col text-[8px]">
                        <span className="font-bold" style={{ color: currentConfig.textColor }}>{lang === 'ar' ? 'النظام' : 'System'}</span>
                        <span style={{ color: currentConfig.subTextColor }}>3 updates</span>
                      </div>
                    </div>
                  </div>
                  {/* Chats list */}
                  <div className="space-y-2">
                    {[1, 2, 3].map((id) => (
                      <div
                        key={id}
                        className="p-2.5 rounded-xl flex items-center gap-2 border border-white/5"
                        style={{ backgroundColor: currentConfig.cardBgColor || 'rgba(255,255,255,0.05)' }}
                      >
                        <div className="w-8 h-8 rounded-full bg-slate-600/30 flex items-center justify-center text-xs">👤</div>
                        <div className="flex-1 flex flex-col text-[9px]">
                          <span className="font-bold" style={{ color: currentConfig.textColor }}>Ahmed Ali</span>
                          <span style={{ color: currentConfig.subTextColor }}>Hello there! how are you?</span>
                        </div>
                        <span className="text-[8px]" style={{ color: currentConfig.subTextColor }}>10m</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Profile Screen Mockup */}
              {activeTab === 'profile' && (
                <div className="flex-1 flex flex-col px-3 py-2 space-y-4">
                  {/* Avatar section */}
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-full border-2 border-indigo-500 bg-slate-600/20 flex items-center justify-center">👤</div>
                    <div className="flex flex-col">
                      <span className="font-bold text-xs" style={{ color: currentConfig.textColor }}>Legendary User</span>
                      <span className="text-[9px]" style={{ color: currentConfig.subTextColor }}>ID: 12345678</span>
                    </div>
                  </div>
                  {/* Coins Section */}
                  <div
                    className="p-3 rounded-xl flex items-center justify-between border border-white/5"
                    style={{ backgroundColor: currentConfig.cardBgColor || 'rgba(255,255,255,0.05)' }}
                  >
                    <div className="flex items-center gap-2 text-[9px]">
                      <span>💰</span>
                      <span style={{ color: currentConfig.textColor }}>10,500 Coins</span>
                    </div>
                    <span className="text-[8px] px-2 py-0.5 rounded bg-indigo-500/20 text-indigo-400">Recharge</span>
                  </div>
                  {/* Menu Options */}
                  <div className="space-y-1">
                    {['My Wallet', 'Badges Cabinet', 'VIP Center', 'Settings'].map((opt, idx) => (
                      <div
                        key={idx}
                        className="p-2.5 rounded-xl flex items-center justify-between border border-white/5"
                        style={{ backgroundColor: currentConfig.cardBgColor || 'rgba(255,255,255,0.05)' }}
                      >
                        <span className="text-[9px]" style={{ color: currentConfig.textColor }}>{opt}</span>
                        <ChevronRight className="w-3.5 h-3.5" style={{ color: currentConfig.subTextColor }} />
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Private Chat Screen Mockup */}
              {activeTab === 'chat' && (
                <div className="flex-1 flex flex-col px-3 py-2 justify-between">
                  <div className="flex items-center gap-2 border-b border-white/5 pb-2">
                    <ChevronRight className="w-4 h-4 rotate-180" style={{ color: currentConfig.textColor }} />
                    <span className="font-bold text-xs" style={{ color: currentConfig.textColor }}>Private Chat</span>
                  </div>
                  {/* Messages Bubble mockup */}
                  <div className="flex-1 py-4 space-y-3 flex flex-col justify-end">
                    {/* Other bubble */}
                    <div className="flex items-end gap-2 max-w-[80%]">
                      <div className="w-6 h-6 rounded-full bg-slate-600/30 flex items-center justify-center text-[10px]">👤</div>
                      <div
                        className="p-2 rounded-2xl rounded-bl-none text-[9px]"
                        style={{ backgroundColor: currentConfig.bubbleOtherBgColor || '#fff', color: currentConfig.textColor }}
                      >
                        How is the custom theme looking?
                      </div>
                    </div>
                    {/* Self bubble */}
                    <div className="flex items-end gap-2 max-w-[80%] self-end">
                      <div
                        className="p-2 rounded-2xl rounded-br-none text-[9px] text-slate-900"
                        style={{ backgroundColor: currentConfig.bubbleSelfBgColor || '#ffe082' }}
                      >
                        Absolutely stunning! PNG/WebP background working.
                      </div>
                    </div>
                  </div>
                  {/* Chat Input bar */}
                  <div className="flex gap-1 border-t border-white/5 pt-2 items-center">
                    <div className="flex-1 bg-white/5 border border-white/10 rounded-full px-3 py-1 flex items-center justify-between">
                      <span className="text-[9px]" style={{ color: currentConfig.subTextColor }}>Type a message...</span>
                      <Send className="w-3 h-3 text-indigo-400" />
                    </div>
                  </div>
                </div>
              )}

              {/* User Mini Profile Sheet Mockup */}
              {activeTab === 'userProfile' && (
                <div className="flex-1 flex flex-col justify-end">
                  <div
                    className="rounded-t-3xl p-4 space-y-3 relative border-t border-white/10"
                    style={{
                      backgroundColor: currentConfig.backgroundColor || '#16151A',
                      backgroundImage: currentConfig.backgroundImage ? `url(${currentConfig.backgroundImage})` : 'none',
                      backgroundSize: 'cover',
                      color: currentConfig.textColor || '#fff',
                    }}
                  >
                    {/* Centered Avatar */}
                    <div className="flex justify-center -mt-10">
                      <div className="w-16 h-16 rounded-full border-4 border-slate-800 bg-slate-700 flex items-center justify-center text-lg">👤</div>
                    </div>
                    <div className="text-center">
                      <h4 className="font-bold text-xs" style={{ color: currentConfig.textColor }}>Active User</h4>
                      <p className="text-[8px] flex items-center justify-center gap-1 mt-0.5" style={{ color: currentConfig.subTextColor }}>
                        ID: 98765432 <Copy className="w-2.5 h-2.5" />
                      </p>
                    </div>
                    {/* Badges Cabinet */}
                    <div className="p-2 rounded-lg bg-white/5 border border-white/5 flex gap-2 justify-center">
                      {['🏆', '👑', '⭐'].map((emoji, i) => (
                        <span key={i} className="text-xs">{emoji}</span>
                      ))}
                    </div>
                    {/* Buttons */}
                    <div className="flex gap-2">
                      <button
                        className="flex-1 py-1.5 rounded-lg text-[9px] font-bold text-slate-900 shadow-sm"
                        style={{ backgroundColor: currentConfig.buttonColor || '#FFE082' }}
                      >
                        Follow
                      </button>
                      <button
                        className="flex-1 py-1.5 rounded-lg text-[9px] font-bold text-slate-900 shadow-sm"
                        style={{ backgroundColor: currentConfig.buttonColor || '#FFE082' }}
                      >
                        Send Gift
                      </button>
                    </div>
                  </div>
                </div>
              )}

              {/* Event Details Screen Mockup */}
              {activeTab === 'eventInfo' && (
                <div className="flex-1 flex flex-col px-3 py-2 space-y-4">
                  <div className="flex items-center gap-2">
                    <ChevronRight className="w-4 h-4 rotate-180" style={{ color: currentConfig.textColor }} />
                    <span className="font-bold text-xs" style={{ color: currentConfig.textColor }}>Event Information</span>
                  </div>
                  {/* Event Trophy Card */}
                  <div className="h-28 rounded-xl bg-white/5 border border-white/10 flex flex-col items-center justify-center space-y-1">
                    <span className="text-2xl">🏆</span>
                    <span className="text-[10px] font-bold" style={{ color: currentConfig.textColor }}>Grand Championship 2026</span>
                    <span className="text-[8px]" style={{ color: currentConfig.subTextColor }}>Prizes & Gold Coins</span>
                  </div>
                  {/* Event Rewards List */}
                  <div className="space-y-1.5">
                    <div className="p-2 rounded-lg bg-white/5 flex items-center justify-between text-[9px]">
                      <span>🥇 First Place</span>
                      <span className="font-bold" style={{ color: currentConfig.textColor }}>100k Gold Coins</span>
                    </div>
                    <div className="p-2 rounded-lg bg-white/5 flex items-center justify-between text-[9px]">
                      <span>🥈 Second Place</span>
                      <span className="font-bold" style={{ color: currentConfig.textColor }}>50k Gold Coins</span>
                    </div>
                  </div>
                </div>
              )}

              {/* System Notifications Screen Mockup */}
              {activeTab === 'notifications' && (
                <div className="flex-1 flex flex-col px-3 py-2 space-y-4">
                  <div className="flex items-center gap-2">
                    <ChevronRight className="w-4 h-4 rotate-180" style={{ color: currentConfig.textColor }} />
                    <span className="font-bold text-xs" style={{ color: currentConfig.textColor }}>System Notifications</span>
                  </div>
                  {/* Mock notification cards */}
                  <div className="space-y-2">
                    {[1, 2].map((id) => (
                      <div
                        key={id}
                        className="p-2.5 rounded-xl border border-white/5 flex items-start gap-2"
                        style={{ backgroundColor: currentConfig.cardBgColor || 'rgba(255,255,255,0.05)' }}
                      >
                        <div className="w-6 h-6 rounded-full bg-indigo-500/20 flex items-center justify-center text-xs">🔔</div>
                        <div className="flex-1 flex flex-col text-[8px] space-y-0.5">
                          <span className="font-bold" style={{ color: currentConfig.textColor }}>System Alert</span>
                          <span style={{ color: currentConfig.subTextColor }}>You have received a royal crown decoration gift!</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Right Side: Options and Uploader (7 cols) */}
        <div className="lg:col-span-7 bg-[#141417] rounded-2xl border border-white/5 p-6 space-y-6">
          {/* Active Screen Tab Bar Selector */}
          <div className="flex flex-col gap-1.5">
            <label className="text-[10px] uppercase text-slate-400 font-bold">{lang === 'ar' ? 'اختر الشاشة لتخصيصها' : 'Select Screen to Customize'}</label>
            <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
              {screens.map(s => (
                <button
                  key={s.id}
                  onClick={() => setActiveTab(s.id)}
                  className={`px-3 py-2 rounded-xl text-left text-xs font-semibold border transition-all ${
                    activeTab === s.id
                      ? 'bg-indigo-600/10 border-indigo-500 text-indigo-300'
                      : 'bg-white/5 border-transparent text-slate-400 hover:bg-white/10 hover:text-white'
                  }`}
                >
                  {lang === 'ar' ? s.labelAr : s.labelEn}
                </button>
              ))}
            </div>
          </div>

          <hr className="border-white/5" />

          {/* Form Fields for Active Screen */}
          <div className="space-y-4">
            <h3 className="text-white text-xs font-bold uppercase tracking-wider flex items-center gap-1.5">
              <span>🛠️</span> {lang === 'ar' ? 'خيارات مظهر الشاشة' : 'Screen Visual Settings'}
            </h3>

            {/* Background Image Upload */}
            <div className="space-y-1.5">
              <label className="block text-[10px] uppercase text-slate-400 font-bold">
                {lang === 'ar' ? 'صورة الخلفية (PNG/WebP)' : 'Background Image (PNG/WebP)'}
              </label>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder="https://example.com/background.webp"
                  value={currentConfig.backgroundImage || ''}
                  onChange={e => updateField(activeTab, 'backgroundImage', e.target.value)}
                  className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-1.5 px-3 text-xs text-white"
                />
                <label className="cursor-pointer px-3 py-1.5 bg-indigo-600/20 hover:bg-indigo-600/30 text-indigo-400 rounded-lg flex items-center justify-center">
                  <Upload className="w-4 h-4" />
                  <input
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={e => {
                      const file = e.target.files?.[0];
                      if (file) handleImageUpload(file, activeTab, 'backgroundImage');
                    }}
                  />
                </label>
              </div>
            </div>

            {/* Background Color Picker */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <label className="block text-[10px] uppercase text-slate-400 font-bold">
                  {lang === 'ar' ? 'لون الخلفية الأساسي' : 'Background Color'}
                </label>
                <div className="flex gap-2">
                  <input
                    type="color"
                    value={to6Hex(currentConfig.backgroundColor || '#ffffff')}
                    onChange={e => updateField(activeTab, 'backgroundColor', e.target.value)}
                    className="w-10 h-8 p-0.5 bg-[#161618] border border-white/10 rounded-lg"
                  />
                  <input
                    type="text"
                    value={currentConfig.backgroundColor || ''}
                    onChange={e => updateField(activeTab, 'backgroundColor', e.target.value)}
                    className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-1.5 px-3 text-xs text-white"
                  />
                </div>
              </div>

              {/* Text Color Picker */}
              <div className="space-y-1.5">
                <label className="block text-[10px] uppercase text-slate-400 font-bold">
                  {lang === 'ar' ? 'لون النصوص' : 'Text Color'}
                </label>
                <div className="flex gap-2">
                  <input
                    type="color"
                    value={to6Hex(currentConfig.textColor || '#000000')}
                    onChange={e => updateField(activeTab, 'textColor', e.target.value)}
                    className="w-10 h-8 p-0.5 bg-[#161618] border border-white/10 rounded-lg"
                  />
                  <input
                    type="text"
                    value={currentConfig.textColor || ''}
                    onChange={e => updateField(activeTab, 'textColor', e.target.value)}
                    className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-1.5 px-3 text-xs text-white"
                  />
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {/* Optional subTextColor */}
              {'subTextColor' in currentConfig && (
                <div className="space-y-1.5">
                  <label className="block text-[10px] uppercase text-slate-400 font-bold">
                    {lang === 'ar' ? 'لون النصوص الثانوية' : 'Sub-Text Color'}
                  </label>
                  <div className="flex gap-2">
                    <input
                      type="color"
                      value={to6Hex(currentConfig.subTextColor || '#888888')}
                      onChange={e => updateField(activeTab, 'subTextColor', e.target.value)}
                      className="w-10 h-8 p-0.5 bg-[#161618] border border-white/10 rounded-lg"
                    />
                    <input
                      type="text"
                      value={currentConfig.subTextColor || ''}
                      onChange={e => updateField(activeTab, 'subTextColor', e.target.value)}
                      className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-1.5 px-3 text-xs text-white"
                    />
                  </div>
                </div>
              )}

              {/* Optional cardBgColor */}
              {'cardBgColor' in currentConfig && (
                <div className="space-y-1.5">
                  <label className="block text-[10px] uppercase text-slate-400 font-bold">
                    {lang === 'ar' ? 'لون خلفية البطاقات' : 'Card Background Color'}
                  </label>
                  <div className="flex gap-2">
                    <input
                      type="color"
                      value={to6Hex(currentConfig.cardBgColor || '#ffffff')}
                      onChange={e => updateField(activeTab, 'cardBgColor', e.target.value)}
                      className="w-10 h-8 p-0.5 bg-[#161618] border border-white/10 rounded-lg"
                    />
                    <input
                      type="text"
                      value={currentConfig.cardBgColor || ''}
                      onChange={e => updateField(activeTab, 'cardBgColor', e.target.value)}
                      className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-1.5 px-3 text-xs text-white"
                    />
                  </div>
                </div>
              )}

              {/* Optional buttonColor */}
              {'buttonColor' in currentConfig && (
                <div className="space-y-1.5">
                  <label className="block text-[10px] uppercase text-slate-400 font-bold">
                    {lang === 'ar' ? 'لون الأزرار' : 'Button Color'}
                  </label>
                  <div className="flex gap-2">
                    <input
                      type="color"
                      value={to6Hex(currentConfig.buttonColor || '#ffe082')}
                      onChange={e => updateField(activeTab, 'buttonColor', e.target.value)}
                      className="w-10 h-8 p-0.5 bg-[#161618] border border-white/10 rounded-lg"
                    />
                    <input
                      type="text"
                      value={currentConfig.buttonColor || ''}
                      onChange={e => updateField(activeTab, 'buttonColor', e.target.value)}
                      className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-1.5 px-3 text-xs text-white"
                    />
                  </div>
                </div>
              )}

              {/* Chat screen self bubble bg */}
              {'bubbleSelfBgColor' in currentConfig && (
                <div className="space-y-1.5">
                  <label className="block text-[10px] uppercase text-slate-400 font-bold">
                    {lang === 'ar' ? 'لون فقاعة رسائل المرسل (أنا)' : 'Sender Message Bubble (Self)'}
                  </label>
                  <div className="flex gap-2">
                    <input
                      type="color"
                      value={to6Hex(currentConfig.bubbleSelfBgColor || '#ffe082')}
                      onChange={e => updateField(activeTab, 'bubbleSelfBgColor', e.target.value)}
                      className="w-10 h-8 p-0.5 bg-[#161618] border border-white/10 rounded-lg"
                    />
                    <input
                      type="text"
                      value={currentConfig.bubbleSelfBgColor || ''}
                      onChange={e => updateField(activeTab, 'bubbleSelfBgColor', e.target.value)}
                      className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-1.5 px-3 text-xs text-white"
                    />
                  </div>
                </div>
              )}

              {/* Chat screen other bubble bg */}
              {'bubbleOtherBgColor' in currentConfig && (
                <div className="space-y-1.5">
                  <label className="block text-[10px] uppercase text-slate-400 font-bold">
                    {lang === 'ar' ? 'لون فقاعة رسائل المستلم (الآخر)' : 'Receiver Message Bubble (Other)'}
                  </label>
                  <div className="flex gap-2">
                    <input
                      type="color"
                      value={to6Hex(currentConfig.bubbleOtherBgColor || '#ffffff')}
                      onChange={e => updateField(activeTab, 'bubbleOtherBgColor', e.target.value)}
                      className="w-10 h-8 p-0.5 bg-[#161618] border border-white/10 rounded-lg"
                    />
                    <input
                      type="text"
                      value={currentConfig.bubbleOtherBgColor || ''}
                      onChange={e => updateField(activeTab, 'bubbleOtherBgColor', e.target.value)}
                      className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-1.5 px-3 text-xs text-white"
                    />
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
