import { useEffect, useState } from 'react';
import { AppConfig } from '../types';
import { getAppConfig, updateAppConfig } from '../lib/db';
import { uploadToCloudinary } from '../lib/storage';
import { to6Hex } from '../lib/colors';
import ImageUpload from '../components/ImageUpload';
import {
  Save,
  RotateCcw,
  Sparkles,
  Heart,
  BarChart3,
  Sliders,
  Layers,
} from 'lucide-react';

export default function ProfileCustomizePage() {
  const [config, setConfig] = useState<AppConfig>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [activeSection, setActiveSection] = useState<'theme' | 'stats' | 'cp' | 'tabs' | 'icons'>('cp');

  useEffect(() => {
    getAppConfig().then((data) => {
      if (data) {
        const sv = (data as any).screenVisuals?.fullProfile || (data as any).screenVisuals?.userProfile || {};
        setConfig({
          ...data,
          fullProfileDataPanelBg: data.fullProfileDataPanelBg || sv.dataPanelBg || '',
          fullProfileDataPanelDivider: data.fullProfileDataPanelDivider || sv.dataPanelDivider || '',
          fullProfileDataCountColor: data.fullProfileDataCountColor || sv.dataCountColor || '#FFFFFF',
          fullProfileDataLabelColor: data.fullProfileDataLabelColor || sv.dataLabelColor || '#6DE5FF',
          fullProfileVisitorsImage: data.fullProfileVisitorsImage || sv.visitorsImage || '',
          fullProfileFansImage: data.fullProfileFansImage || sv.fansImage || '',
          fullProfileFollowersImage: data.fullProfileFollowersImage || sv.followersImage || '',
          fullProfileGiftsImage: data.fullProfileGiftsImage || sv.giftsImage || '',
          fullProfileSentGiftsImage: data.fullProfileSentGiftsImage || sv.sentGiftsImage || '',
          fullProfileCpCardBg: data.fullProfileCpCardBg || sv.cpCardBg || '',
          fullProfileCpCardBorder: data.fullProfileCpCardBorder || sv.cpCardBorder || '#DE880F',
          fullProfileCpRingSvga: data.fullProfileCpRingSvga || sv.cpRingSvga || '',
          fullProfileCpRing2Svga: data.fullProfileCpRing2Svga || sv.cpRing2Svga || '',
          fullProfileCpRing3Svga: data.fullProfileCpRing3Svga || sv.cpRing3Svga || '',
          fullProfileCpMidDecorImage: data.fullProfileCpMidDecorImage || sv.cpMidDecorImage || '',
          fullProfileCpDaysBg: data.fullProfileCpDaysBg || sv.cpDaysBg || '',
          fullProfileCpAddIcon: data.fullProfileCpAddIcon || sv.cpAddIcon || '',
          fullProfileMedalsCardBg: data.fullProfileMedalsCardBg || sv.medalsCardBg || '',
          fullProfileMedalsCardBorder: data.fullProfileMedalsCardBorder || sv.medalsCardBorder || '#26DE880F',
          fullProfileTabActiveColor: data.fullProfileTabActiveColor || sv.tabActiveColor || '#00E5C9',
          fullProfileTabInactiveColor: data.fullProfileTabInactiveColor || sv.tabInactiveColor || '#99FFFFFF',
          fullProfileEditIcon: data.fullProfileEditIcon || (data as any).profileEditIcon || sv.profileEditIcon || '',
        });
      }
      setLoading(false);
    });
  }, []);

  const handleSave = async () => {
    setSaving(true);
    try {
      const fullProfileVisuals = {
        backgroundImage: (config as any).profileBackgroundImage || '',
        backgroundColor: (config as any).profileSolidColor || '#16151A',
        textColor: (config as any).fullProfileTextColor || '#FFFFFF',
        subTextColor: (config as any).fullProfileSubTextColor || '#9BA1B6',
        dataPanelBg: (config as any).fullProfileDataPanelBg || '',
        dataPanelDivider: (config as any).fullProfileDataPanelDivider || '',
        dataCountColor: (config as any).fullProfileDataCountColor || '#FFFFFF',
        dataLabelColor: (config as any).fullProfileDataLabelColor || '#6DE5FF',
        visitorsImage: (config as any).fullProfileVisitorsImage || '',
        fansImage: (config as any).fullProfileFansImage || '',
        followersImage: (config as any).fullProfileFollowersImage || '',
        giftsImage: (config as any).fullProfileGiftsImage || '',
        sentGiftsImage: (config as any).fullProfileSentGiftsImage || '',
        cpCardBg: (config as any).fullProfileCpCardBg || '',
        cpCardBorder: (config as any).fullProfileCpCardBorder || '#DE880F',
        cpRingSvga: (config as any).fullProfileCpRingSvga || '',
        cpRing2Svga: (config as any).fullProfileCpRing2Svga || '',
        cpRing3Svga: (config as any).fullProfileCpRing3Svga || '',
        cpMidDecorImage: (config as any).fullProfileCpMidDecorImage || '',
        cpDaysBg: (config as any).fullProfileCpDaysBg || '',
        cpAddIcon: (config as any).fullProfileCpAddIcon || '',
        medalsCardBg: (config as any).fullProfileMedalsCardBg || '',
        medalsCardBorder: (config as any).fullProfileMedalsCardBorder || '#26DE880F',
        tabActiveColor: (config as any).fullProfileTabActiveColor || '#00E5C9',
        tabInactiveColor: (config as any).fullProfileTabInactiveColor || '#99FFFFFF',
        profileEditIcon: (config as any).fullProfileEditIcon || (config as any).profileEditIcon || '',
        profileSettingsIcon: (config as any).profileSettingsIcon || '',
        profileShareIcon: (config as any).profileShareIcon || '',
        profileChatIcon: (config as any).profileChatIcon || '',
        profileGiftIcon: (config as any).profileGiftIcon || '',
        profileReportIcon: (config as any).profileReportIcon || '',
      };

      const existingVisuals = (config as any).screenVisuals || {};
      const updatedScreenVisuals = {
        ...existingVisuals,
        fullProfile: {
          ...(existingVisuals.fullProfile || {}),
          ...fullProfileVisuals,
        },
        userProfile: {
          ...(existingVisuals.userProfile || {}),
          ...fullProfileVisuals,
        },
      };

      await updateAppConfig({
        ...config,
        screenVisuals: updatedScreenVisuals,
        fullProfileDataPanelBg: fullProfileVisuals.dataPanelBg,
        fullProfileDataPanelDivider: fullProfileVisuals.dataPanelDivider,
        fullProfileDataCountColor: fullProfileVisuals.dataCountColor,
        fullProfileDataLabelColor: fullProfileVisuals.dataLabelColor,
        fullProfileVisitorsImage: fullProfileVisuals.visitorsImage,
        fullProfileFansImage: fullProfileVisuals.fansImage,
        fullProfileFollowersImage: fullProfileVisuals.followersImage,
        fullProfileGiftsImage: fullProfileVisuals.giftsImage,
        fullProfileSentGiftsImage: fullProfileVisuals.sentGiftsImage,
        fullProfileCpCardBg: fullProfileVisuals.cpCardBg,
        fullProfileCpCardBorder: fullProfileVisuals.cpCardBorder,
        fullProfileCpRingSvga: fullProfileVisuals.cpRingSvga,
        fullProfileCpRing2Svga: fullProfileVisuals.cpRing2Svga,
        fullProfileCpRing3Svga: fullProfileVisuals.cpRing3Svga,
        fullProfileCpMidDecorImage: fullProfileVisuals.cpMidDecorImage,
        fullProfileCpDaysBg: fullProfileVisuals.cpDaysBg,
        fullProfileCpAddIcon: fullProfileVisuals.cpAddIcon,
        fullProfileMedalsCardBg: fullProfileVisuals.medalsCardBg,
        fullProfileMedalsCardBorder: fullProfileVisuals.medalsCardBorder,
        fullProfileTabActiveColor: fullProfileVisuals.tabActiveColor,
        fullProfileTabInactiveColor: fullProfileVisuals.tabInactiveColor,
        fullProfileEditIcon: fullProfileVisuals.profileEditIcon,
      });

      alert('تم حفظ إعدادات البروفايل بنجاح! التغييرات ستظهر فوراً في التطبيق.');
    } catch (e: any) {
      alert('خطأ أثناء الحفظ: ' + e.message);
    } finally {
      setSaving(false);
    }
  };

  const resetAll = () => {
    if (!confirm('هل أنت متأكد من استعادة الإعدادات الافتراضية للبروفايل؟')) return;
    setConfig((p) => ({
      ...p,
      profileBgType: 'solid',
      profileSolidColor: '#16151A',
      profileBackgroundImage: '',
      fullProfileDataPanelBg: '',
      fullProfileDataPanelDivider: '',
      fullProfileDataCountColor: '#FFFFFF',
      fullProfileDataLabelColor: '#6DE5FF',
      fullProfileVisitorsImage: '',
      fullProfileFansImage: '',
      fullProfileFollowersImage: '',
      fullProfileGiftsImage: '',
      fullProfileSentGiftsImage: '',
      fullProfileCpCardBg: '',
      fullProfileCpCardBorder: '#DE880F',
      fullProfileCpRingSvga: '',
      fullProfileCpRing2Svga: '',
      fullProfileCpRing3Svga: '',
      fullProfileCpMidDecorImage: '',
      fullProfileCpDaysBg: '',
      fullProfileCpAddIcon: '',
      fullProfileMedalsCardBg: '',
      fullProfileMedalsCardBorder: '#26DE880F',
      fullProfileTabActiveColor: '#00E5C9',
      fullProfileTabInactiveColor: '#99FFFFFF',
      fullProfileEditIcon: '',
    }));
  };

  if (loading) return <div className="text-slate-400 text-xs p-6">جارٍ التحميل...</div>;

  const bgType = (config as any).profileBgType || 'solid';
  const gradientColors = (config as any).profileGradientColors || ['#1E1E2C', '#03030A'];

  return (
    <div className="space-y-6 max-w-5xl pb-16">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-white/5 pb-4">
        <div>
          <h2 className="text-white text-xl font-bold flex items-center gap-2">
            <span className="p-2 rounded-xl bg-indigo-500/10 text-indigo-400">👤</span>
            تخصيص البروفايل المتكامل (Full Profile Customizer)
          </h2>
          <p className="text-slate-400 text-xs mt-1">
            تحكم كامل في شاشة البروفايل الشخصي: شريط الإحصائيات، كرت الارتباط وخواتم SVGA، الأوسمة، والتبويبات والأيقونات.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={resetAll}
            className="flex items-center gap-2 bg-[#1A1A24] hover:bg-[#2A2A3A] text-slate-300 text-xs font-medium px-4 py-2.5 rounded-xl transition-all"
          >
            <RotateCcw className="w-4 h-4" /> استعادة الافتراضي
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-500 disabled:bg-indigo-800 text-white text-xs font-semibold px-5 py-2.5 rounded-xl shadow-lg shadow-indigo-600/20 transition-all"
          >
            <Save className="w-4 h-4" />
            {saving ? 'جارٍ الحفظ...' : 'حفظ التعديلات'}
          </button>
        </div>
      </div>

      {/* Navigation Tabs */}
      <div className="flex flex-wrap gap-2 border-b border-white/5 pb-3">
        {[
          { id: 'cp', label: 'كرت الارتباط وخواتم SVGA (CP)', icon: Heart },
          { id: 'stats', label: 'شريط الإحصائيات (الزوار، المعجبون، الهدايا)', icon: BarChart3 },
          { id: 'theme', label: 'الخلفية والمظهر العام', icon: Layers },
          { id: 'tabs', label: 'التبويبات وكروت الأوسمة', icon: Sparkles },
          { id: 'icons', label: 'الأيقونات وأزرار التحكم', icon: Sliders },
        ].map((tab) => {
          const Icon = tab.icon;
          const isActive = activeSection === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveSection(tab.id as any)}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold transition-all ${
                isActive
                  ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/25'
                  : 'bg-[#141417] text-slate-400 hover:text-white hover:bg-[#1C1C22] border border-white/5'
              }`}
            >
              <Icon className="w-4 h-4" />
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* TAB 1: CP Card & SVGA Rings */}
      {activeSection === 'cp' && (
        <div className="space-y-6">
          <div className="bg-[#141417] rounded-2xl border border-white/5 p-6 space-y-6">
            <div className="flex items-center gap-2 border-b border-white/5 pb-3">
              <Heart className="w-5 h-5 text-pink-500" />
              <div>
                <h3 className="text-white text-sm font-bold">كرت الارتباط وخواتم الـ SVGA (CP Card)</h3>
                <p className="text-slate-400 text-xs">
                  تخصيص كامل لكرت الارتباط الموحد تحت شريط الإحصائيات: الخلفية، الإطار، وخواتم SVGA المتحركة لكل مستوى.
                </p>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-xs font-bold text-slate-300 mb-2">خلفية كرت الارتباط (CP Card Background)</label>
                <ImageUpload
                  currentUrl={(config as any).fullProfileCpCardBg}
                  onUpload={(file) => uploadToCloudinary(file, 'profile_cp')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileCpCardBg: url }))}
                  label="رفع خلفية كرت CP"
                  accept="image/*"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 mb-2">لون إطار الكرت (Border Color)</label>
                <div className="flex gap-2 items-center">
                  <input
                    type="color"
                    value={to6Hex(((config as any).fullProfileCpCardBorder as string) || '#DE880F')}
                    onChange={(e) => setConfig((p) => ({ ...p, fullProfileCpCardBorder: e.target.value }))}
                    className="w-10 h-10 rounded cursor-pointer bg-transparent border border-white/10 shrink-0"
                  />
                  <input
                    type="text"
                    value={(config as any).fullProfileCpCardBorder || '#DE880F'}
                    onChange={(e) => setConfig((p) => ({ ...p, fullProfileCpCardBorder: e.target.value }))}
                    className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white font-mono"
                  />
                </div>
              </div>
            </div>

            <div className="border-t border-white/5 pt-4">
              <h4 className="text-white text-xs font-bold mb-3 flex items-center gap-1.5">
                <Sparkles className="w-4 h-4 text-amber-400" />
                رسوم خواتم الارتباط بصيغة SVGA المتحركة
              </h4>
              <p className="text-slate-400 text-[11px] mb-4">
                يتم تشغيل الرسوم المتحركة في منتصف كرت الارتباط بين الصورتين الشخصيتين بدقة وسلاسة فائقة.
              </p>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="bg-[#18181D] p-4 rounded-xl border border-white/5">
                  <label className="block text-xs font-bold text-amber-300 mb-1">خاتم المستوى 1 (Ring 1 SVGA)</label>
                  <p className="text-[10px] text-slate-500 mb-2">الافتراضي: assets/svga/cp1.svga</p>
                  <ImageUpload
                    currentUrl={(config as any).fullProfileCpRingSvga}
                    onUpload={(file) => uploadToCloudinary(file, 'profile_rings')}
                    onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileCpRingSvga: url }))}
                    label="رفع خاتم SVGA 1"
                    accept=".svga,image/*"
                  />
                </div>

                <div className="bg-[#18181D] p-4 rounded-xl border border-white/5">
                  <label className="block text-xs font-bold text-slate-300 mb-1">خاتم المستوى 2 (Ring 2 SVGA)</label>
                  <p className="text-[10px] text-slate-500 mb-2">الافتراضي: assets/svga/cp2.svga</p>
                  <ImageUpload
                    currentUrl={(config as any).fullProfileCpRing2Svga}
                    onUpload={(file) => uploadToCloudinary(file, 'profile_rings')}
                    onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileCpRing2Svga: url }))}
                    label="رفع خاتم SVGA 2"
                    accept=".svga,image/*"
                  />
                </div>

                <div className="bg-[#18181D] p-4 rounded-xl border border-white/5">
                  <label className="block text-xs font-bold text-pink-300 mb-1">خاتم المستوى 3 (Ring 3 SVGA)</label>
                  <p className="text-[10px] text-slate-500 mb-2">الافتراضي: assets/svga/cp3.svga</p>
                  <ImageUpload
                    currentUrl={(config as any).fullProfileCpRing3Svga}
                    onUpload={(file) => uploadToCloudinary(file, 'profile_rings')}
                    onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileCpRing3Svga: url }))}
                    label="رفع خاتم SVGA 3"
                    accept=".svga,image/*"
                  />
                </div>
              </div>
            </div>

            <div className="border-t border-white/5 pt-4 grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-300 mb-2">زينة القلب في المنتصف (Heart Mid Decor)</label>
                <ImageUpload
                  currentUrl={(config as any).fullProfileCpMidDecorImage}
                  onUpload={(file) => uploadToCloudinary(file, 'profile_cp')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileCpMidDecorImage: url }))}
                  label="رفع زينة القلب"
                  accept="image/*"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 mb-2">خلفية شارة عدد الأيام (Days Badge Bg)</label>
                <ImageUpload
                  currentUrl={(config as any).fullProfileCpDaysBg}
                  onUpload={(file) => uploadToCloudinary(file, 'profile_cp')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileCpDaysBg: url }))}
                  label="رفع خلفية شارة الأيام"
                  accept="image/*"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 mb-2">أيقونة إضافة شريك (Add CP Icon)</label>
                <ImageUpload
                  currentUrl={(config as any).fullProfileCpAddIcon}
                  onUpload={(file) => uploadToCloudinary(file, 'profile_cp')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileCpAddIcon: url }))}
                  label="رفع أيقونة إضافة CP"
                  accept="image/*"
                />
              </div>
            </div>
          </div>
        </div>
      )}

      {/* TAB 2: Stats Panel Customizer */}
      {activeSection === 'stats' && (
        <div className="space-y-6">
          <div className="bg-[#141417] rounded-2xl border border-white/5 p-6 space-y-6">
            <div className="flex items-center gap-2 border-b border-white/5 pb-3">
              <BarChart3 className="w-5 h-5 text-indigo-400" />
              <div>
                <h3 className="text-white text-sm font-bold">شريط الإحصائيات (الزوار، المعجبون، المتابعون، الهدايا، المرسلة)</h3>
                <p className="text-slate-400 text-xs">
                  يمكنك استبدال الكلمات الكلاسيكية بصور أو ملصقات ملونة، وتعديل الخلفية والفاصل ولون الأرقام.
                </p>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-xs font-bold text-slate-300 mb-2">خلفية الشريط بالكامل (Data Panel Background)</label>
                <ImageUpload
                  currentUrl={(config as any).fullProfileDataPanelBg}
                  onUpload={(file) => uploadToCloudinary(file, 'profile_stats')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileDataPanelBg: url }))}
                  label="رفع خلفية الشريط"
                  accept="image/*"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 mb-2">صورة الفاصل بين الإحصائيات (Divider Image)</label>
                <ImageUpload
                  currentUrl={(config as any).fullProfileDataPanelDivider}
                  onUpload={(file) => uploadToCloudinary(file, 'profile_stats')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileDataPanelDivider: url }))}
                  label="رفع صورة الفاصل"
                  accept="image/*"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 mb-2">لون الأرقام (Count Color)</label>
                <div className="flex gap-2 items-center">
                  <input
                    type="color"
                    value={to6Hex(((config as any).fullProfileDataCountColor as string) || '#FFFFFF')}
                    onChange={(e) => setConfig((p) => ({ ...p, fullProfileDataCountColor: e.target.value }))}
                    className="w-10 h-10 rounded cursor-pointer bg-transparent border border-white/10 shrink-0"
                  />
                  <input
                    type="text"
                    value={(config as any).fullProfileDataCountColor || '#FFFFFF'}
                    onChange={(e) => setConfig((p) => ({ ...p, fullProfileDataCountColor: e.target.value }))}
                    className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white font-mono"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 mb-2">لون العناوين النصية (Label Color)</label>
                <div className="flex gap-2 items-center">
                  <input
                    type="color"
                    value={to6Hex(((config as any).fullProfileDataLabelColor as string) || '#6DE5FF')}
                    onChange={(e) => setConfig((p) => ({ ...p, fullProfileDataLabelColor: e.target.value }))}
                    className="w-10 h-10 rounded cursor-pointer bg-transparent border border-white/10 shrink-0"
                  />
                  <input
                    type="text"
                    value={(config as any).fullProfileDataLabelColor || '#6DE5FF'}
                    onChange={(e) => setConfig((p) => ({ ...p, fullProfileDataLabelColor: e.target.value }))}
                    className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white font-mono"
                  />
                </div>
              </div>
            </div>

            <div className="border-t border-white/5 pt-4">
              <h4 className="text-white text-xs font-bold mb-1">استبدال أسماء الإحصائيات بصور أو ملصقات</h4>
              <p className="text-slate-400 text-[11px] mb-4">
                عند رفع صورة لأي عنصر، سيتم عرض الصورة مباشرة تحت الرقم بدلاً من النص العادي.
              </p>

              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
                <div className="bg-[#18181D] p-3 rounded-xl border border-white/5">
                  <label className="block text-xs font-bold text-indigo-300 mb-1">الزوار (Visitors)</label>
                  <ImageUpload
                    currentUrl={(config as any).fullProfileVisitorsImage}
                    onUpload={(file) => uploadToCloudinary(file, 'profile_stats')}
                    onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileVisitorsImage: url }))}
                    label="صورة الزوار"
                    accept="image/*"
                  />
                </div>

                <div className="bg-[#18181D] p-3 rounded-xl border border-white/5">
                  <label className="block text-xs font-bold text-indigo-300 mb-1">المعجبون (Fans)</label>
                  <ImageUpload
                    currentUrl={(config as any).fullProfileFansImage}
                    onUpload={(file) => uploadToCloudinary(file, 'profile_stats')}
                    onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileFansImage: url }))}
                    label="صورة المعجبون"
                    accept="image/*"
                  />
                </div>

                <div className="bg-[#18181D] p-3 rounded-xl border border-white/5">
                  <label className="block text-xs font-bold text-indigo-300 mb-1">المتابعون (Followers)</label>
                  <ImageUpload
                    currentUrl={(config as any).fullProfileFollowersImage}
                    onUpload={(file) => uploadToCloudinary(file, 'profile_stats')}
                    onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileFollowersImage: url }))}
                    label="صورة المتابعون"
                    accept="image/*"
                  />
                </div>

                <div className="bg-[#18181D] p-3 rounded-xl border border-white/5">
                  <label className="block text-xs font-bold text-indigo-300 mb-1">الهدايا (Gifts)</label>
                  <ImageUpload
                    currentUrl={(config as any).fullProfileGiftsImage}
                    onUpload={(file) => uploadToCloudinary(file, 'profile_stats')}
                    onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileGiftsImage: url }))}
                    label="صورة الهدايا"
                    accept="image/*"
                  />
                </div>

                <div className="bg-[#18181D] p-3 rounded-xl border border-white/5">
                  <label className="block text-xs font-bold text-indigo-300 mb-1">المرسلة (Sent Gifts)</label>
                  <ImageUpload
                    currentUrl={(config as any).fullProfileSentGiftsImage}
                    onUpload={(file) => uploadToCloudinary(file, 'profile_stats')}
                    onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileSentGiftsImage: url }))}
                    label="صورة المرسلة"
                    accept="image/*"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* TAB 3: Background & Theme */}
      {activeSection === 'theme' && (
        <div className="space-y-6">
          <div className="bg-[#141417] rounded-2xl border border-white/5 p-6 space-y-4">
            <h3 className="text-white text-sm font-semibold">خلفية الشاشة العامة (Profile Background)</h3>

            <div>
              <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1.5">نوع الخلفية (Background Type)</label>
              <select
                value={bgType}
                onChange={(e) => setConfig((p) => ({ ...p, profileBgType: e.target.value }))}
                className="w-full bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white"
              >
                <option value="solid">Solid Color (لون ثابت)</option>
                <option value="gradient">Gradient (تدرج لوني)</option>
                <option value="image">Image (صورة)</option>
              </select>
            </div>

            {bgType === 'solid' && (
              <div>
                <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1.5">اللون الثابت</label>
                <div className="flex gap-2 items-center">
                  <input
                    type="color"
                    value={to6Hex(((config as any).profileSolidColor as string) || '#16151A')}
                    onChange={(e) => setConfig((p) => ({ ...p, profileSolidColor: e.target.value }))}
                    className="w-10 h-10 rounded cursor-pointer bg-transparent border border-white/10 shrink-0"
                  />
                  <input
                    type="text"
                    value={(config as any).profileSolidColor || '#16151A'}
                    onChange={(e) => setConfig((p) => ({ ...p, profileSolidColor: e.target.value }))}
                    className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white font-mono"
                  />
                </div>
              </div>
            )}

            {bgType === 'gradient' && (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1.5">بداية التدرج</label>
                  <div className="flex gap-2 items-center">
                    <input
                      type="color"
                      value={to6Hex(gradientColors[0])}
                      onChange={(e) => {
                        const newColors = [...gradientColors];
                        newColors[0] = e.target.value;
                        setConfig((p) => ({ ...p, profileGradientColors: newColors }));
                      }}
                      className="w-10 h-10 rounded cursor-pointer bg-transparent border border-white/10 shrink-0"
                    />
                    <input
                      type="text"
                      value={gradientColors[0]}
                      onChange={(e) => {
                        const newColors = [...gradientColors];
                        newColors[0] = e.target.value;
                        setConfig((p) => ({ ...p, profileGradientColors: newColors }));
                      }}
                      className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white font-mono"
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1.5">نهاية التدرج</label>
                  <div className="flex gap-2 items-center">
                    <input
                      type="color"
                      value={to6Hex(gradientColors[1] || '#000000')}
                      onChange={(e) => {
                        const newColors = [...gradientColors];
                        newColors[1] = e.target.value;
                        setConfig((p) => ({ ...p, profileGradientColors: newColors }));
                      }}
                      className="w-10 h-10 rounded cursor-pointer bg-transparent border border-white/10 shrink-0"
                    />
                    <input
                      type="text"
                      value={gradientColors[1] || '#000000'}
                      onChange={(e) => {
                        const newColors = [...gradientColors];
                        newColors[1] = e.target.value;
                        setConfig((p) => ({ ...p, profileGradientColors: newColors }));
                      }}
                      className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white font-mono"
                    />
                  </div>
                </div>
              </div>
            )}

            {bgType === 'image' && (
              <div>
                <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1.5">صورة الخلفية</label>
                <ImageUpload
                  currentUrl={(config as any).profileBackgroundImage}
                  onUpload={(file) => uploadToCloudinary(file, 'profile')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, profileBackgroundImage: url }))}
                  label="رفع صورة خلفية البروفايل"
                  accept="image/*"
                />
              </div>
            )}
          </div>
        </div>
      )}

      {/* TAB 4: Tabs & Medals Cards */}
      {activeSection === 'tabs' && (
        <div className="space-y-6">
          <div className="bg-[#141417] rounded-2xl border border-white/5 p-6 space-y-6">
            <div className="flex items-center gap-2 border-b border-white/5 pb-3">
              <Sparkles className="w-5 h-5 text-teal-400" />
              <div>
                <h3 className="text-white text-sm font-bold">التبويبات السفلية وكروت الأوسمة (Tabs & Medals)</h3>
                <p className="text-slate-400 text-xs">
                  التحكم في ألوان التبويبات (معرض الهدايا، جدار الأوسمة، الملحقات) وخلفيات كروت النقاط والترتيب.
                </p>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-xs font-bold text-slate-300 mb-2">لون التبويب النشط (Tab Active Color)</label>
                <div className="flex gap-2 items-center">
                  <input
                    type="color"
                    value={to6Hex(((config as any).fullProfileTabActiveColor as string) || '#00E5C9')}
                    onChange={(e) => setConfig((p) => ({ ...p, fullProfileTabActiveColor: e.target.value }))}
                    className="w-10 h-10 rounded cursor-pointer bg-transparent border border-white/10 shrink-0"
                  />
                  <input
                    type="text"
                    value={(config as any).fullProfileTabActiveColor || '#00E5C9'}
                    onChange={(e) => setConfig((p) => ({ ...p, fullProfileTabActiveColor: e.target.value }))}
                    className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white font-mono"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 mb-2">لون التبويب غير النشط (Tab Inactive Color)</label>
                <div className="flex gap-2 items-center">
                  <input
                    type="color"
                    value={to6Hex(((config as any).fullProfileTabInactiveColor as string) || '#99FFFFFF')}
                    onChange={(e) => setConfig((p) => ({ ...p, fullProfileTabInactiveColor: e.target.value }))}
                    className="w-10 h-10 rounded cursor-pointer bg-transparent border border-white/10 shrink-0"
                  />
                  <input
                    type="text"
                    value={(config as any).fullProfileTabInactiveColor || '#99FFFFFF'}
                    onChange={(e) => setConfig((p) => ({ ...p, fullProfileTabInactiveColor: e.target.value }))}
                    className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white font-mono"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 mb-2">خلفية كروت الأوسمة (Medals Card Bg)</label>
                <ImageUpload
                  currentUrl={(config as any).fullProfileMedalsCardBg}
                  onUpload={(file) => uploadToCloudinary(file, 'profile_medals')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileMedalsCardBg: url }))}
                  label="رفع خلفية كروت الأوسمة"
                  accept="image/*"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 mb-2">إطار كروت الأوسمة (Medals Card Border)</label>
                <div className="flex gap-2 items-center">
                  <input
                    type="color"
                    value={to6Hex(((config as any).fullProfileMedalsCardBorder as string) || '#DE880F')}
                    onChange={(e) => setConfig((p) => ({ ...p, fullProfileMedalsCardBorder: e.target.value }))}
                    className="w-10 h-10 rounded cursor-pointer bg-transparent border border-white/10 shrink-0"
                  />
                  <input
                    type="text"
                    value={(config as any).fullProfileMedalsCardBorder || '#DE880F'}
                    onChange={(e) => setConfig((p) => ({ ...p, fullProfileMedalsCardBorder: e.target.value }))}
                    className="flex-1 bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white font-mono"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* TAB 5: Action Buttons & Classic Icons */}
      {activeSection === 'icons' && (
        <div className="space-y-6">
          <div className="bg-[#141417] rounded-2xl border border-white/5 p-6 space-y-4">
            <h3 className="text-white text-sm font-semibold">الأيقونات الكلاسيكية وأزرار التحكم</h3>
            <p className="text-slate-400 text-xs">
              استبدال الأيقونات الكلاسيكية بروابط أو صور جديدة لتحديث مظهر البروفايل بالكامل.
            </p>

            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
              <div className="bg-[#18181D] p-3 rounded-xl border border-white/5">
                <label className="block text-xs font-bold text-slate-300 mb-1">أيقونة التعديل (Edit Profile Icon)</label>
                <ImageUpload
                  currentUrl={(config as any).fullProfileEditIcon || (config as any).profileEditIcon}
                  onUpload={(file) => uploadToCloudinary(file, 'profile_icons')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, fullProfileEditIcon: url, profileEditIcon: url }))}
                  label="أيقونة التعديل"
                  accept="image/*"
                />
              </div>

              <div className="bg-[#18181D] p-3 rounded-xl border border-white/5">
                <label className="block text-xs font-bold text-slate-300 mb-1">أيقونة الإعدادات (Settings Icon)</label>
                <ImageUpload
                  currentUrl={(config as any).profileSettingsIcon}
                  onUpload={(file) => uploadToCloudinary(file, 'profile_icons')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, profileSettingsIcon: url }))}
                  label="أيقونة الإعدادات"
                  accept="image/*"
                />
              </div>

              <div className="bg-[#18181D] p-3 rounded-xl border border-white/5">
                <label className="block text-xs font-bold text-slate-300 mb-1">أيقونة المشاركة (Share Icon)</label>
                <ImageUpload
                  currentUrl={(config as any).profileShareIcon}
                  onUpload={(file) => uploadToCloudinary(file, 'profile_icons')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, profileShareIcon: url }))}
                  label="أيقونة المشاركة"
                  accept="image/*"
                />
              </div>

              <div className="bg-[#18181D] p-3 rounded-xl border border-white/5">
                <label className="block text-xs font-bold text-slate-300 mb-1">أيقونة الدردشة (Chat Icon)</label>
                <ImageUpload
                  currentUrl={(config as any).profileChatIcon}
                  onUpload={(file) => uploadToCloudinary(file, 'profile_icons')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, profileChatIcon: url }))}
                  label="أيقونة الدردشة"
                  accept="image/*"
                />
              </div>

              <div className="bg-[#18181D] p-3 rounded-xl border border-white/5">
                <label className="block text-xs font-bold text-slate-300 mb-1">أيقونة الهدية (Gift Icon)</label>
                <ImageUpload
                  currentUrl={(config as any).profileGiftIcon}
                  onUpload={(file) => uploadToCloudinary(file, 'profile_icons')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, profileGiftIcon: url }))}
                  label="أيقونة الهدية"
                  accept="image/*"
                />
              </div>

              <div className="bg-[#18181D] p-3 rounded-xl border border-white/5">
                <label className="block text-xs font-bold text-slate-300 mb-1">أيقونة الإبلاغ (Report Icon)</label>
                <ImageUpload
                  currentUrl={(config as any).profileReportIcon}
                  onUpload={(file) => uploadToCloudinary(file, 'profile_icons')}
                  onUrlChange={(url) => setConfig((p) => ({ ...p, profileReportIcon: url }))}
                  label="أيقونة الإبلاغ"
                  accept="image/*"
                />
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
