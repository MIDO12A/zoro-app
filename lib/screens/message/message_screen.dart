import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/r.dart';
import '../../services/supabase_service.dart';
import '../../providers/user_provider.dart';
import 'message_reply_detail_screen.dart';
import '../notifications/notifications_screen.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final SupabaseService _firebaseService = SupabaseService();
  List<Map<String, dynamic>> _conversations = [];
  StreamSubscription? _conversationsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConversations());
  }

  void _loadConversations() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    if (user == null) return;

    _conversationsSub = _firebaseService.conversationsStream(user.uid).listen((convos) {
      if (mounted) {
        setState(() => _conversations = convos);
      }
    });
  }

  @override
  void dispose() {
    _conversationsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final String title = isAr ? 'رسالة' : 'Message';
    final String eventInfoLabel = isAr ? 'معلومات\nالحدث' : 'Event\ninformation';
    final String systemNotifLabel = isAr ? 'إشعار\nالنظام' : 'System\nnotification';

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            // Header Stack (Title and Background arch decoration only)
            Stack(
              alignment: Alignment.topCenter,
              children: [
                R.image(
                  R.discoverHeaderBg,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 20),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF16151A),
                    ),
                  ),
                ),
              ],
            ),

            // Info Cards (Event Info and System Notifications) placed BELOW the header
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16),
              child: Row(
                children: isAr
                    ? [
                        // Right Card (Event Info)
                        Expanded(
                          child: _buildInfoCard(
                            bgAsset: R.chatMessageInformationBg,
                            label: eventInfoLabel,
                            badgeCount: 2,
                            isAr: isAr,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isAr ? 'معلومات الحدث قريباً' : 'Event information coming soon')),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Left Card (System Notification)
                        Expanded(
                          child: _buildInfoCard(
                            bgAsset: R.chatMessageSystemBg,
                            label: systemNotifLabel,
                            badgeCount: 3,
                            isAr: isAr,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                              );
                            },
                          ),
                        ),
                      ]
                    : [
                        // Left Card (System Notification)
                        Expanded(
                          child: _buildInfoCard(
                            bgAsset: R.chatMessageSystemBg,
                            label: systemNotifLabel,
                            badgeCount: 3,
                            isAr: isAr,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Right Card (Event Info)
                        Expanded(
                          child: _buildInfoCard(
                            bgAsset: R.chatMessageInformationBg,
                            label: eventInfoLabel,
                            badgeCount: 2,
                            isAr: isAr,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isAr ? 'معلومات الحدث قريباً' : 'Event information coming soon')),
                              );
                            },
                          ),
                        ),
                      ],
              ),
            ),
            Expanded(
              child: _buildConversationList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String bgAsset,
    required String label,
    required int badgeCount,
    required bool isAr,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 2.15,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: R.image(bgAsset, fit: BoxFit.fill),
            ),
            Positioned(
              top: 14,
              left: isAr ? null : 16,
              right: isAr ? 16 : null,
              child: Text(
                label,
                textAlign: isAr ? TextAlign.right : TextAlign.left,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -5,
                left: isAr ? -5 : null,
                right: isAr ? null : -5,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE82323),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationList() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final String emptyText = isAr ? 'لا توجد دردشات لـ الكل' : 'No Conversation for All';

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            R.image(
              R.mipmap('common_empty_ic_1'),
              width: 140,
              height: 140,
            ),
            const SizedBox(height: 16),
            Text(
              emptyText,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF16151A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        return _buildConversationItem(
          conversationId: conv['conversationId'] as String? ?? '',
          otherUid: conv['otherUid'] as String? ?? '',
          otherName: conv['otherName'] as String? ?? '',
          otherPhotoUrl: conv['otherPhotoUrl'] as String? ?? '',
          lastMessage: conv['lastMessage'] as String? ?? '',
          lastMessageTime: conv['lastMessageTime'] as int? ?? 0,
          unread: conv['unreadCount'] as int? ?? 0,
        );
      },
    );
  }

  Widget _buildConversationItem({
    required String conversationId,
    required String otherUid,
    required String otherName,
    required String otherPhotoUrl,
    required String lastMessage,
    required int lastMessageTime,
    required int unread,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MessageReplyDetailScreen(
              conversationId: conversationId,
              otherUid: otherUid,
              otherName: otherName,
              otherPhotoUrl: otherPhotoUrl,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey.shade200,
                  child: ClipOval(
                    child: otherPhotoUrl.isNotEmpty
                        ? Image(image: R.cachedImage(otherPhotoUrl),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Image.asset(R.avaBoy,
                                    width: 56, height: 56, fit: BoxFit.cover))
                        : R.image(R.avaBoy,
                            width: 56, height: 56, fit: BoxFit.cover),
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16151A),
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(lastMessageTime),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9BA1B6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9BA1B6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}
