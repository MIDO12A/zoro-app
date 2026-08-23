import 'package:flutter/material.dart';
import '../../config/r.dart';
import '../../config/app_colors.dart';

class RoomAdminsScreen extends StatelessWidget {
  final String roomId;

  const RoomAdminsScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final admins = _mockAdmins();
    final navH = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0F0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: admins.length,
                separatorBuilder: (_, __) => Container(height: 0.5, color: const Color(0x1AFFFFFF)),
                itemBuilder: (_, i) => _buildAdminItem(context, admins[i]),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, navH + 16),
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.giftBtnGradient,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'إضافة مشرف',
                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: R.image(R.backIc, width: 24, height: 24),
            ),
          ),
          const Spacer(),
          const Text('مدراء الغرفة', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
          const Spacer(),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildAdminItem(BuildContext context, _AdminUser user) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          ClipOval(
            child: R.image(
              user.avatar,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.nickname, style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: AppColors.giftBtnGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('مدير', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('ID: ${user.id}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('إزالة', style: TextStyle(fontSize: 12, color: AppColors.muteRed)),
            ),
          ),
        ],
      ),
    );
  }

  List<_AdminUser> _mockAdmins() {
    return [
      _AdminUser('أحمد', R.avaBoy, '101'),
      _AdminUser('سارة', R.avaGirl, '102'),
      _AdminUser('محمد', R.avaBoy, '103'),
      _AdminUser('نورة', R.avaGirl, '104'),
      _AdminUser('خالد', R.avaBoy, '105'),
      _AdminUser('مريم', R.avaGirl, '106'),
    ];
  }
}

class _AdminUser {
  final String nickname;
  final String avatar;
  final String id;

  _AdminUser(this.nickname, this.avatar, this.id);
}
