import 'package:flutter/material.dart';
import '../../core/cache/encrypted_image_provider.dart';
import '../../services/dynamic_config_service.dart';
import 'cp_service.dart';

class CcSettingScreen extends StatefulWidget {
  const CcSettingScreen({super.key});

  @override
  State<CcSettingScreen> createState() => _CcSettingScreenState();
}

class _CcSettingScreenState extends State<CcSettingScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _couple;
  Map<String, dynamic>? _partner;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await CpService.getMyData();
      final couple = data['couple'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _couple = couple;
          _partner = couple?['partner'] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _confirmDissolve() {
    final cfg = DynamicConfigService();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cfg.cpHeaderBg,
        title: Text('فك الارتباط', style: TextStyle(color: cfg.cpHeaderText)),
        content: const Text('هل أنت متأكد؟ لا يمكن التراجع.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: TextStyle(color: cfg.cpSubText))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await CpService.endCp();
              _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: cfg.cpButtonColor),
            child: Text('تأكيد', style: TextStyle(color: cfg.cpButtonTextColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = DynamicConfigService();
    final hasCp = _couple != null;
    final myAvatar = _couple?['user1_avatar'] as String?;
    final partnerAvatar = _partner?['avatar'] as String?;
    final myName = _couple?['user1_name'] as String? ?? '';
    final partnerName = _partner?['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: cfg.cpHeaderBg,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cfg.cpGold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white54)))
              : Stack(
                  children: [
                    Column(
                      children: [
                        _assetWidget(cfg.cpHeaderBgImage, 'assets/cp/ic_cp_setting_bg_top.webp',
                            width: double.infinity, fit: BoxFit.fitWidth,
                            errorBuilder: (_, __, ___) => const SizedBox(height: 200, child: ColoredBox(color: Color(0xFF4d1522)))),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(top: 23),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                              color: cfg.cpHeaderBg,
                              border: Border(top: BorderSide(color: cfg.cpCardBorder, width: 1)),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(14, 48, 14, 40),
                              child: Column(
                                children: [
                                  // Token panel
                                  _buildInfoPanel(cfg,
                                    title: 'رمز الحب',
                                    icon: Icons.favorite,
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 10),
                                        Text('سجل رمز الحب', style: TextStyle(color: cfg.cpSubText, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Letter panel
                                  _buildInfoPanel(cfg,
                                    title: 'رسالة حب',
                                    icon: Icons.mail_outline,
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 10),
                                        GestureDetector(
                                          onTap: () {},
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('السجل', style: TextStyle(color: Colors.white, fontSize: 14)),
                                              const SizedBox(width: 4),
                                              Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.7), size: 14),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  // Dissolve button
                                  if (hasCp) ...[
                                    Container(
                                      width: double.infinity,
                                      height: 44,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(57),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                      ),
                                      child: MaterialButton(
                                        onPressed: _confirmDissolve,
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.heart_broken, color: Colors.white, size: 16),
                                            SizedBox(width: 8),
                                            Text('فك الارتباط', style: TextStyle(color: Colors.white, fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('بعد فك الارتباط، ستفقد جميع بيانات العلاقة',
                                        style: TextStyle(color: cfg.cpSubText, fontSize: 12)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top,
                      left: 0, right: 0,
                      child: SizedBox(
                        height: kToolbarHeight,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                    // CP panel (centered over bg)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
                      left: 0, right: 0,
                      child: Center(
                        child: SizedBox(
                          width: 250,
                          child: Column(
                            children: [
                              // Two frames side by side
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildAvatarFrame(cfg, myAvatar, 70),
                                  Container(
                                    width: 36, height: 36,
                                    color: cfg.cpGold,
                                    child: Icon(Icons.favorite, size: 24),
                                  ),
                                  _buildAvatarFrame(cfg, partnerAvatar, 70),
                                ],
                              ),
                              const SizedBox(height: 2),
                              if (hasCp)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(myName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                    const SizedBox(width: 16),
                                    Text(partnerName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _assetWidget(String cfgPath, String fallback, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    if (cfgPath.isNotEmpty) {
      return Image.asset(cfgPath,
          width: width, height: height, fit: fit, alignment: alignment,
          errorBuilder: errorBuilder ?? (_, __, ___) => Image.asset(fallback,
              width: width, height: height, fit: fit, alignment: alignment));
    }
    return Image.asset(fallback,
        width: width, height: height, fit: fit, alignment: alignment,
        errorBuilder: errorBuilder);
  }

  Widget _buildAvatarFrame(DynamicConfigService cfg, String? url, double size) {
    Widget avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      backgroundImage: url != null && url.isNotEmpty ? EncryptedImageProvider(url) : null,
      child: url == null || url.isEmpty
          ? Icon(Icons.person, size: size * 0.5, color: Colors.white.withValues(alpha: 0.5))
          : null,
    );
    return Container(
      width: size + 8, height: size + 8,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(cfg.cpLeftFrame.isNotEmpty
              ? cfg.cpLeftFrame
              : 'assets/cp/ic_cp_wing_frame_left.webp'),
        ),
      ),
      child: Center(child: avatar),
    );
  }

  Widget _buildInfoPanel(DynamicConfigService cfg, {required String title, required IconData icon, required Widget child}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: cfg.cpCardBg.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cfg.cpCardBorder, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: cfg.cpGold, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
