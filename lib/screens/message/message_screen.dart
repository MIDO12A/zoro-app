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

class _MessageScreenState extends State<MessageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _firebaseService = SupabaseService();
  List<Map<String, dynamic>> _conversations = [];
  StreamSubscription? _conversationsSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            Stack(
              children: [
                R.image(
                  R.discoverHeaderBg,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      const Text(
                        'الرسائل',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16151A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                bgAsset: R.chatMessageSystemBg,
                                label: 'الاشعارات',
                                badgeCount: 0,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInfoCard(
                                bgAsset: R.chatMessageInformationBg,
                                label: 'معلومات الحدث',
                                badgeCount: 0,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('معلومات الحدث قريباً')),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF1E90FF),
                ),
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF16151A),
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                tabs: const [
                  Tab(text: 'الكل'),
                  Tab(text: 'الرسائل'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildConversationList(),
                  _buildConversationList(),
                ],
              ),
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
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          R.image(bgAsset, width: double.infinity, fit: BoxFit.fitWidth),
          Positioned(
            top: 8,
            right: 8,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: 0,
              right: 0,
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
    );
  }

  Widget _buildConversationList() {
    if (_conversations.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد محادثات',
          style: TextStyle(fontSize: 15, color: Color(0xFF9BA1B6)),
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
