import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/r.dart';
import '../../config/app_colors.dart';
import '../../services/supabase_service.dart';

class BlacklistScreen extends StatefulWidget {
  final String roomId;

  const BlacklistScreen({super.key, required this.roomId});

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  final SupabaseService _firebaseService = SupabaseService();
  List<Map<String, dynamic>> _bannedUsers = [];
  StreamSubscription? _banSub;

  @override
  void initState() {
    super.initState();
    _loadBannedUsers();
  }

  void _loadBannedUsers() {
    _firebaseService.getRoomBlockedUsers(widget.roomId).then((users) {
      if (mounted) setState(() => _bannedUsers = users);
    });
  }

  @override
  void dispose() {
    _banSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0F0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _bannedUsers.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: _bannedUsers.length,
                      separatorBuilder: (_, __) => Container(height: 0.5, color: const Color(0x1AFFFFFF)),
                      itemBuilder: (_, i) => _buildBannedItem(context, _bannedUsers[i]),
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
          const Text('القائمة السوداء', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
          const Spacer(),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.2), size: 64),
          const SizedBox(height: 16),
          const Text(
            'لا يوجد مستخدمين محظورين',
            style: TextStyle(fontSize: 15, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildBannedItem(BuildContext context, Map<String, dynamic> ban) {
    final uid = ban['blocked_uid']?.toString() ?? '';
    final reason = ban['reason']?.toString() ?? 'No reason';
    final nickname = uid.isNotEmpty ? ((1000000 + uid.hashCode.abs() % 9000000).toString()) : 'Unknown';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          ClipOval(
            child: R.image(
              R.avaBoy,
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
                Text(nickname, style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  'السبب: $reason',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              _firebaseService.unblockUserFromRoom(widget.roomId, uid);
              setState(() => _bannedUsers.removeWhere((b) => b['blocked_uid']?.toString() == uid));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User unbanned'), duration: Duration(seconds: 2)),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.goldLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('فك الحظر', style: TextStyle(fontSize: 12, color: AppColors.goldLight)),
            ),
          ),
        ],
      ),
    );
  }
}
