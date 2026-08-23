import 'package:flutter/material.dart';
import '../../services/dynamic_config_service.dart';

class CcTaskScreen extends StatelessWidget {
  const CcTaskScreen({super.key});

  static const _tasks = [
    {
      'icon': 'assets/cp/ic_cp_val_heart.png',
      'name': 'دردشة مع الشريك',
      'desc': 'أرسل 10 رسائل لشريكك اليوم',
      'plus_val': '+50',
      'status': 'انطلق',
    },
    {
      'icon': 'assets/cp/ic_cp_val_heart.png',
      'name': 'إرسال هدية',
      'desc': 'أرسل هدية لشريكك',
      'plus_val': '+100',
      'status': 'انطلق',
    },
    {
      'icon': 'assets/cp/ic_cp_val_heart.png',
      'name': 'مكالمة صوتية',
      'desc': 'قم بإجراء مكالمة مع شريكك لمدة 5 دقائق',
      'plus_val': '+80',
      'status': 'انطلق',
    },
    {
      'icon': 'assets/cp/ic_cp_val_heart.png',
      'name': 'مشاركة لحظة',
      'desc': 'شارك صورة أو فيديو مع شريكك',
      'plus_val': '+30',
      'status': 'انطلق',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final cfg = DynamicConfigService();

    return Scaffold(
      backgroundColor: cfg.cpHeaderBg,
      body: Stack(
        children: [
          // Top background
          _assetWidget(cfg.cpHeaderBgImage,
            'assets/cp/ic_relationship_task_top_bg.webp',
            width: double.infinity,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          // Scrollable content
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: kToolbarHeight + 40),
                // Toolbar + guide button area
                _buildHeaderAvatars(context),
                const SizedBox(height: 12),
                _buildProgressSection(cfg),
                const SizedBox(height: 33),
                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Text(
                    'أكمل المهام اليومية لجمع النقاط وتعزيز علاقتك',
                    style: TextStyle(
                      color: cfg.cpSubText,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 33),
                // Down bg
                _assetWidget(cfg.cpMineBg,
                  'assets/cp/ic_cp_space_down_bg.webp',
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
                // Today total score panel (overlapping downBg)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Transform.translate(
                    offset: const Offset(0, -30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        gradient: LinearGradient(
                          colors: [cfg.cpGradientStart, cfg.cpGradientEnd],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(
                          color: cfg.cpCardBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'نقاط التفاعل',
                            style: TextStyle(
                                color: cfg.cpHeaderText, fontSize: 16),
                          ),
                          const Spacer(),
                          Text(
                            'ربحت اليوم',
                            style: TextStyle(
                                color: cfg.cpHeaderText, fontSize: 14),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '0',
                            style: TextStyle(
                                color: cfg.cpHeaderText, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Task list
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: _tasks.map((task) => _buildTaskItem(cfg, task)).toList(),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          // Toolbar overlay
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // Guide button (pill shape)
                  Container(
                    margin: const EdgeInsetsDirectional.only(end: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(55),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'دليل',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom bind button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: cfg.cpHeaderBg,
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: _assetWidget('', 'assets/cp/ic_bind_relationship_btn.webp',
                      fit: BoxFit.fitWidth,
                      errorBuilder: (_, __, ___) => Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              cfg.cpGold,
                              cfg.cpGold.withValues(alpha: 0.7)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'اربط علاقة الآن',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cfg.cpHeaderText,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAvatars(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 21, 26, 0),
      child: Row(
        children: [
          // My header (72dp)
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            child: Icon(Icons.person,
                size: 40, color: Colors.white.withValues(alpha: 0.5)),
          ),
          // The other header (overlap -7dp)
          Transform.translate(
            offset: const Offset(-7, 0),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              child: Icon(Icons.person,
                  size: 40, color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(width: 10),
          // Engagement score + progress score
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'نقاط التفاعل',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '0',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(DynamicConfigService cfg) {
    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.3,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor:
                  AlwaysStoppedAnimation<Color>(cfg.cpGold),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Start score and end score
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10',
                  style: TextStyle(color: cfg.cpHeaderText, fontSize: 12)),
              Text('120',
                  style: TextStyle(color: cfg.cpHeaderText, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskItem(DynamicConfigService cfg, Map<String, dynamic> task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cfg.cpCardBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cfg.cpCardBorder, width: 1),
      ),
      child: Row(
        children: [
          // Icon
          _assetWidget('', task['icon'] as String,
            width: 40,
            height: 40,
            errorBuilder: (_, __, ___) => Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cfg.cpGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.favorite,
                  color: cfg.cpGold, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          // Name + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        task['name'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      task['plus_val'] as String,
                      style: const TextStyle(
                        color: Color(0xFFfe4136),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 141),
                  child: Text(
                    task['desc'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Status button
          Container(
            width: 88,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cfg.cpGold,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'انطلق',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
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
}
