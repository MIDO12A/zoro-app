import 'package:flutter/material.dart';
import '../../config/r.dart';
import '../../services/dynamic_config_service.dart';

class EventInfoScreen extends StatelessWidget {
  const EventInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final bgImg = DynamicConfigService().eventInfoBackgroundImage;
    final bgColor = DynamicConfigService().eventInfoBackgroundColor;
    final textColor = DynamicConfigService().eventInfoTextColor;
    final subTextColor = DynamicConfigService().eventInfoSubTextColor;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        image: bgImg.isNotEmpty
            ? DecorationImage(
                image: R.cachedImage(bgImg),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            isAr ? 'معلومات الحدث' : 'Event Information',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Event Banner Placeholder
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: textColor.withOpacity(0.1)),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.emoji_events,
                      size: 64,
                      color: textColor.withOpacity(0.4),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Event Card Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: textColor.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'مسابقة الصيف الكبرى لعام 2026' : 'Grand Summer Championship 2026',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: subTextColor),
                          const SizedBox(width: 6),
                          Text(
                            isAr ? 'تاريخ البدء: 1 سبتمبر 2026' : 'Starts: Sept 1, 2026',
                            style: TextStyle(fontSize: 12, color: subTextColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isAr
                            ? 'أهلاً بكم في بطولة الصيف الكبرى! شاركوا في غرف الدردشة المفضلة لديكم، قوموا بإرسال الهدايا، واجمعوا النقاط لتصدر جدول الترتيب الأسبوعي والفوز بجوائز ذهبية حصرية وإطارات مميزة للملفات الشخصية.'
                            : 'Welcome to the Grand Summer Championship! Join your favorite chat rooms, send gifts, and collect points to top the weekly leaderboard and win exclusive gold rewards and custom profile frames.',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.85),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Rewards Section Header
                Text(
                  isAr ? 'الجوائز والمكافآت' : 'Rewards & Prizes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildRewardItem(
                  isAr ? 'المركز الأول: 100,000 عملة + إطار ذهبي ملكي' : '1st Place: 100,000 Coins + Royal Gold Frame',
                  Icons.looks_one,
                  const Color(0xFFFFD54F),
                  textColor,
                ),
                _buildRewardItem(
                  isAr ? 'المركز الثاني: 50,000 عملة + إطار فضي فاخر' : '2nd Place: 50,000 Coins + Premium Silver Frame',
                  Icons.looks_two,
                  const Color(0xFFC0C0C0),
                  textColor,
                ),
                _buildRewardItem(
                  isAr ? 'المركز الثالث: 25,000 عملة + إطار برونزي كلاسيكي' : '3rd Place: 25,000 Coins + Classic Bronze Frame',
                  Icons.looks_3,
                  const Color(0xFFCD7F32),
                  textColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardItem(String text, IconData icon, Color iconColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
