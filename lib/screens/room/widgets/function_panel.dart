import 'package:flutter/material.dart';
import '../../../config/r.dart';
import '../../../services/dynamic_config_service.dart';

class FunctionPanel extends StatelessWidget {
  final VoidCallback? onClose;
  final void Function(String label)? onItemTap;
  final bool isOwner;
  final bool isModerator;

  const FunctionPanel({
    super.key,
    this.onClose,
    this.onItemTap,
    this.isOwner = false,
    this.isModerator = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final interactionItems = [
      {
        'key': 'Magic Farm',
        'label': isAr ? 'المزرعة السحرية' : 'Magic Farm',
        'asset': '',
      },
      {
        'key': 'PK Team',
        'label': isAr ? 'فريق بي كي' : 'PK Team',
        'asset': '',
      },
      {
        'key': 'Lucky Bag',
        'label': isAr ? 'حقيبة الحظ' : 'Lucky Bag',
        'asset': '',
      },
    ];

    final functionItems = [
      {
        'key': 'Settings',
        'label': isAr ? 'إعداد الغرفة' : 'Room Settings',
        'asset': R.roomSetSetIc,
      },
      {
        'key': 'Gift Value',
        'label': isAr ? 'قيمة الهدية' : 'Gift Value',
        'asset': R.roomSetGiftIc,
      },
      {
        'key': 'Mixer',
        'label': isAr ? 'خلاط' : 'Mixer',
        'asset': R.roomSetMixerIc,
      },
      {
        'key': 'Volume',
        'label': isAr ? 'مستوى صوت الغرفة' : 'Room Volume',
        'asset': R.roomSetVolumeIc,
      },
        {
          'key': 'Seat Style',
          'label': isAr ? 'شكل المقاعد' : 'Seat Style',
          'asset': R.roomSetSeatStyle,
        },
      if (isOwner)
        {
          'key': 'Room Background',
          'label': isAr ? 'خلفية الغرفة' : 'Room Background',
          'asset': R.roomSetSeatStyle, // Reusing icon for now
        },
      {
        'key': 'Mute Mic',
        'label': isAr ? 'إيقاف الميكروفون' : 'Mute Mic',
        'asset': '',
      },
      {
        'key': 'Mic Mode',
        'label': isAr ? 'نمط الميكروفون' : 'Mic Mode',
        'asset': '',
      },
    ];

    final effectItems = [
      {
        'key': 'Clear Messages',
        'label': isAr ? 'مسح الرسائل' : 'Clear Messages',
        'asset': '',
      },
      {
        'key': 'Message Settings',
        'label': isAr ? 'إعدادات الرسائل' : 'Message Settings',
        'asset': '',
      },
      {
        'key': 'Effect',
        'label': isAr ? 'إعدادات التأثيرات' : 'Effects Settings',
        'asset': R.roomSetEffectIc,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: DynamicConfigService().roomFunctionsPanelBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.only(top: 20, bottom: 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(context, isAr ? 'تفاعل الغرفة' : 'Room Interaction', interactionItems),
            const SizedBox(height: 24),
            _buildSection(context, isAr ? 'وظائف الغرفة' : 'Room Functions', functionItems),
            const SizedBox(height: 24),
            _buildSection(context, isAr ? 'إعدادات التأثيرات' : 'إعدادات التأثيرات', effectItems),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Map<String, String>> items) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            title,
            textAlign: isAr ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 16,
            alignment: isAr ? WrapAlignment.end : WrapAlignment.start,
            children: items.map((item) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 4,
                child: GestureDetector(
                  onTap: () {
                    final key = item['key']!;
                    if (key == 'Settings' || key == 'Mixer' || key == 'Volume' || key == 'Seat Style' || key == 'Effect') {
                      onItemTap?.call(key);
                    } else {
                      final label = item['label']!;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isAr ? '$label قريباً' : '$label coming soon'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _getIconWidget(item['key']!, item['asset']),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          item['label']!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _getIconWidget(String labelKey, String? assetPath) {
    if (assetPath != null && assetPath.isNotEmpty) {
      return Image.asset(
        assetPath,
        width: 48,
        height: 48,
        errorBuilder: (_, __, ___) => _fallbackIcon(labelKey),
      );
    }
    return _fallbackIcon(labelKey);
  }

  Widget _fallbackIcon(String labelKey) {
    switch (labelKey) {
      case 'Magic Farm':
        return _buildItemIcon(Icons.forest, [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]);
      case 'PK Team':
        return _buildItemIcon(Icons.local_fire_department, [const Color(0xFFFF5722), const Color(0xFFD84315)]);
      case 'Lucky Bag':
        return _buildItemIcon(Icons.shopping_bag, [const Color(0xFFFFC107), const Color(0xFFE65100)]);
      case 'Gift Value':
        return _buildItemIcon(Icons.card_giftcard, [const Color(0xFFE91E63), const Color(0xFFC2185B)]);
      case 'Mute Mic':
        return _buildItemIcon(Icons.mic_off, [const Color(0xFF78909C), const Color(0xFF455A64)]);
      case 'Mic Mode':
        return _buildItemIcon(Icons.mic, [const Color(0xFF26A69A), const Color(0xFF00796B)]);
      case 'Clear Messages':
        return _buildItemIcon(Icons.cleaning_services, [const Color(0xFF42A5F5), const Color(0xFF1565C0)]);
      case 'Message Settings':
        return _buildItemIcon(Icons.chat_bubble_outline, [const Color(0xFFAB47BC), const Color(0xFF6A1B9A)]);
      default:
        return _buildItemIcon(Icons.settings, [const Color(0xFF90A4AE), const Color(0xFF37474F)]);
    }
  }

  Widget _buildItemIcon(IconData icon, List<Color> gradientColors) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}
