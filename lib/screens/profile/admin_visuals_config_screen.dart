import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restart_app/restart_app.dart';
import '../../services/dynamic_config_service.dart';
import '../../config/r.dart';

class AdminVisualsConfigScreen extends StatefulWidget {
  const AdminVisualsConfigScreen({super.key});

  @override
  State<AdminVisualsConfigScreen> createState() => _AdminVisualsConfigScreenState();
}

class _AdminVisualsConfigScreenState extends State<AdminVisualsConfigScreen> {
  final _db = FirebaseFirestore.instance;
  final _cfg = DynamicConfigService();
  bool _loading = false;

  // Controllers for general details
  final _appNameController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _splashUrlController = TextEditingController();
  final _borderRadiusController = TextEditingController();

  // Controllers for colors
  final _primaryBgController = TextEditingController();
  final _textPrimaryController = TextEditingController();
  final _textSecondaryController = TextEditingController();
  final _goldColorController = TextEditingController();
  final _buttonColorController = TextEditingController();
  final _buttonTextColorController = TextEditingController();
  final _headerColorController = TextEditingController();
  final _tabBarColorController = TextEditingController();

  // Controllers for titles
  final _discoverTitleController = TextEditingController();
  final _messageTitleController = TextEditingController();
  final _profileTitleController = TextEditingController();

  // Map to hold asset overrides
  final Map<String, TextEditingController> _assetOverrideControllers = {};

  // Map to hold icon overrides
  final Map<String, TextEditingController> _iconOverrideControllers = {};

  final List<Map<String, String>> _commonAssets = [
    {
      'path': 'assets/mipmap-xxhdpi/room_mic_seat_default_circle.png',
      'label': 'مقعد دائري فارغ ومفتوح (Game Style)',
    },
    {
      'path': 'assets/mipmap-xxhdpi/room_mic_seat_lock_circle.png',
      'label': 'مقعد دائري مقفل (Game Style)',
    },
    {
      'path': 'assets/mipmap-xxhdpi/room_mic_seat_default_vip_2_ic.webp',
      'label': 'مقعد الـ VIP الفارغ (Heart Style)',
    },
    {
      'path': 'assets/mipmap-xxhdpi/room_mic_seat_default_ic.webp',
      'label': 'مقعد كلاسيكي فارغ (Classic Style)',
    },
    {
      'path': 'assets/mipmap-xxhdpi/room_bg_friend.webp',
      'label': 'صورة خلفية الغرفة الافتراضية',
    },
  ];

  final List<Map<String, String>> _commonIcons = [
    {
      'key': 'room_exit_ic',
      'label': 'أيقونة خروج الغرفة (Exit)',
    },
    {
      'key': 'room_chat_ic',
      'label': 'أيقونة الدردشة والكتابة',
    },
    {
      'key': 'room_emoj_ic',
      'label': 'أيقونة الإيموجي والتفاعل',
    },
    {
      'key': 'room_gift_ic',
      'label': 'أيقونة الهدايا بالأسفل',
    },
    {
      'key': 'room_micphone_ic',
      'label': 'أيقونة الميكروفون المفتوح',
    },
    {
      'key': 'room_function_ic',
      'label': 'أيقونة التروس للإعدادات (Settings)',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentValues();
  }

  void _loadCurrentValues() {
    // General
    _appNameController.text = _cfg.appName;
    _logoUrlController.text = _cfg.logoUrl;
    _splashUrlController.text = _cfg.splashUrl;
    _borderRadiusController.text = _cfg.borderRadius.toString();

    // Colors
    _primaryBgController.text = _colorToHex(_cfg.primaryBg);
    _textPrimaryController.text = _colorToHex(_cfg.textPrimary);
    _textSecondaryController.text = _colorToHex(_cfg.textSecondary);
    _goldColorController.text = _colorToHex(_cfg.goldColor);
    _buttonColorController.text = _colorToHex(_cfg.buttonColor);
    _buttonTextColorController.text = _colorToHex(_cfg.buttonTextColor);
    _headerColorController.text = _colorToHex(_cfg.headerColor);
    _tabBarColorController.text = _colorToHex(_cfg.tabBarColor);

    // Titles
    _discoverTitleController.text = _cfg.discoverTitle;
    _messageTitleController.text = _cfg.messageTitle;
    _profileTitleController.text = _cfg.profileTitle;

    // Asset Overrides
    for (final item in _commonAssets) {
      final path = item['path']!;
      _assetOverrideControllers[path] = TextEditingController(
        text: _cfg.assetsOverride[path] ?? '',
      );
    }

    // Icon Overrides
    for (final item in _commonIcons) {
      final key = item['key']!;
      _iconOverrideControllers[key] = TextEditingController(
        text: _cfg.iconOverrides[key] ?? '',
      );
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}';
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _logoUrlController.dispose();
    _splashUrlController.dispose();
    _borderRadiusController.dispose();
    _primaryBgController.dispose();
    _textPrimaryController.dispose();
    _textSecondaryController.dispose();
    _goldColorController.dispose();
    _buttonColorController.dispose();
    _buttonTextColorController.dispose();
    _headerColorController.dispose();
    _tabBarColorController.dispose();
    _discoverTitleController.dispose();
    _messageTitleController.dispose();
    _profileTitleController.dispose();
    for (var controller in _assetOverrideControllers.values) {
      controller.dispose();
    }
    for (var controller in _iconOverrideControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveConfig() async {
    setState(() => _loading = true);
    try {
      // 1. General Info
      await _db.collection('app_config').doc('appName').set({'value': _appNameController.text});
      await _db.collection('app_config').doc('logoUrl').set({'value': _logoUrlController.text});
      await _db.collection('app_config').doc('splashGifUrl').set({'value': _splashUrlController.text});
      await _db.collection('app_config').doc('borderRadius').set({'value': int.tryParse(_borderRadiusController.text) ?? 8});

      // 2. Colors
      await _db.collection('app_config').doc('primaryBg').set({'value': _primaryBgController.text});
      await _db.collection('app_config').doc('textPrimary').set({'value': _textPrimaryController.text});
      await _db.collection('app_config').doc('textSecondary').set({'value': _textSecondaryController.text});
      await _db.collection('app_config').doc('goldColor').set({'value': _goldColorController.text});
      await _db.collection('app_config').doc('buttonColor').set({'value': _buttonColorController.text});
      await _db.collection('app_config').doc('buttonTextColor').set({'value': _buttonTextColorController.text});
      await _db.collection('app_config').doc('headerColor').set({'value': _headerColorController.text});
      await _db.collection('app_config').doc('tabBarColor').set({'value': _tabBarColorController.text});

      // 3. Tab Titles
      await _db.collection('app_config').doc('discoverTitle').set({'value': _discoverTitleController.text});
      await _db.collection('app_config').doc('messageTitle').set({'value': _messageTitleController.text});
      await _db.collection('app_config').doc('profileTitle').set({'value': _profileTitleController.text});

      // 4. Asset Overrides
      final assetOverridesMap = <String, String>{};
      _assetOverrideControllers.forEach((key, controller) {
        if (controller.text.trim().isNotEmpty) {
          assetOverridesMap[key] = controller.text.trim();
        }
      });
      await _db.collection('app_config').doc('assetsOverrides').set({'value': assetOverridesMap});

      // 5. Icon Overrides
      final iconOverridesMap = <String, String>{};
      _iconOverrideControllers.forEach((key, controller) {
        if (controller.text.trim().isNotEmpty) {
          iconOverridesMap[key] = controller.text.trim();
        }
      });
      await _db.collection('app_config').doc('iconOverrides').set({'value': iconOverridesMap});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ وتحديث الإعدادات على السيرفر بنجاح!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restartApp() async {
    setState(() => _loading = true);
    try {
      // Force all connected devices to hot restart by setting restartApp flag
      await _db.collection('app_config').doc('restartApp').set({'value': true});
      await Future.delayed(const Duration(seconds: 1));
      Restart.restartApp();
    } catch (_) {
      Restart.restartApp();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffix,
          labelStyle: const TextStyle(color: Color(0xFF9BA1B6), fontSize: 13),
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF16151A).withOpacity(0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFFD54F)),
          ),
        ),
      ),
    );
  }

  Widget _buildColorField({
    required String label,
    required TextEditingController controller,
  }) {
    return _buildTextField(
      label: label,
      controller: controller,
      hint: '#FFFFFF',
      suffix: Container(
        margin: const EdgeInsets.all(8),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _parseHexColor(controller.text),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
      ),
    );
  }

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16151A),
      appBar: AppBar(
        title: const Text(
          'تعديل المظهر والأيقونات',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF16151A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
              children: [
                const Text(
                  'لوحة تحكم المظهر المباشر',
                  style: TextStyle(color: Color(0xFFFFD54F), fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'يمكنك هنا تعديل جميع صور ومقاعد وألوان وأيقونات التطبيق فورياً دون الحاجة لتحديث الكود.',
                  style: TextStyle(color: Color(0xFF9BA1B6), fontSize: 12),
                ),
                const SizedBox(height: 16),

                // ── 1. General details ──
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    iconColor: const Color(0xFFFFD54F),
                    collapsedIconColor: Colors.white30,
                    title: const Text('البيانات العامة للملف الشخصي والتطبيق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    children: [
                      _buildTextField(label: 'اسم التطبيق', controller: _appNameController),
                      _buildTextField(label: 'رابط الشعار (Logo URL)', controller: _logoUrlController),
                      _buildTextField(label: 'رابط واجهة البداية (Splash GIF/Image URL)', controller: _splashUrlController),
                      _buildTextField(label: 'درجة انحناء الزوايا (Border Radius)', controller: _borderRadiusController, keyboardType: TextInputType.number),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10),

                // ── 2. Colors ──
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    iconColor: const Color(0xFFFFD54F),
                    collapsedIconColor: Colors.white30,
                    title: const Text('الألوان والثيمات الأساسية للتطبيق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    children: [
                      _buildColorField(label: 'اللون الخلفي الرئيسي للواجهات', controller: _primaryBgController),
                      _buildColorField(label: 'لون النصوص الأساسية الداكنة', controller: _textPrimaryController),
                      _buildColorField(label: 'لون النصوص الفرعية/الرمادية', controller: _textSecondaryController),
                      _buildColorField(label: 'اللون الذهبي للتنبيهات والتقدم', controller: _goldColorController),
                      _buildColorField(label: 'لون الأزرار والروابط التفاعلية', controller: _buttonColorController),
                      _buildColorField(label: 'لون نص الأزرار', controller: _buttonTextColorController),
                      _buildColorField(label: 'لون رأس الصفحة (Header)', controller: _headerColorController),
                      _buildColorField(label: 'لون شريط التبويبات بالأسفل (Tab Bar)', controller: _tabBarColorController),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10),

                // ── 3. Screen Titles ──
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    iconColor: const Color(0xFFFFD54F),
                    collapsedIconColor: Colors.white30,
                    title: const Text('أسماء وعناوين صفحات التطبيق الرئيسية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    children: [
                      _buildTextField(label: 'عنوان صفحة الغرف/الاستكشاف (Discover)', controller: _discoverTitleController),
                      _buildTextField(label: 'عنوان صفحة الرسائل وغرف الشات (Messages)', controller: _messageTitleController),
                      _buildTextField(label: 'عنوان صفحة حسابي (Profile)', controller: _profileTitleController),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10),

                // ── 4. App icons overrides ──
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    iconColor: const Color(0xFFFFD54F),
                    collapsedIconColor: Colors.white30,
                    title: const Text('أيقونات الشاشات وداخل الغرف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    children: [
                      const Text(
                        'ضع رابط الصورة (PNG/WebP/SVGA) لاستبدال أيقونات الغرفة والتحكم تلقائياً.',
                        style: TextStyle(color: Color(0xFF9BA1B6), fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      for (final item in _commonIcons)
                        _buildTextField(
                          label: item['label']!,
                          controller: _iconOverrideControllers[item['key']!]!,
                          hint: 'رابط الصورة لاستبدال الأيقونة',
                        ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10),

                // ── 5. App assets overrides (seats & backgrounds) ──
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    iconColor: const Color(0xFFFFD54F),
                    collapsedIconColor: Colors.white30,
                    title: const Text('تعديل صور ومقاعد وتأثيرات الغرف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    children: [
                      const Text(
                        'انسخ رابط الصورة (PNG/WebP/SVGA) وضعها لتعديل المقاعد الفارغة أو المغلقة أو خلفية الغرف مباشرة.',
                        style: TextStyle(color: Color(0xFF9BA1B6), fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      for (final item in _commonAssets)
                        _buildTextField(
                          label: item['label']!,
                          controller: _assetOverrideControllers[item['path']!]!,
                          hint: 'مثال: https://myhost.com/new_chair.png',
                        ),
                    ],
                  ),
                ),
              ],
            ),

            if (_loading)
              Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFD54F)),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF16151A),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _saveConfig,
                  icon: const Icon(Icons.save_rounded, color: Colors.black87),
                  label: const Text('حفظ التعديلات', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD54F),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _restartApp,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFFD54F)),
                  label: const Text('تطبيق وإعادة تشغيل', style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFFD54F)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
