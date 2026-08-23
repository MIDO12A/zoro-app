import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/r.dart';
import '../../config/app_colors.dart';
import '../../services/cloudinary_service.dart';
import '../../services/supabase_service.dart';
import 'room_admins_screen.dart';
import 'blacklist_screen.dart';
import 'reports_admin_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// RoomSettingsScreen — activity_room_set.xml
//
// ─ Header background image (room_create_room_bg)
// ─ Title icon (room_create_label_ic) + "Room Settings"
// ─ Room image 108×108 + camera icon overlay (room_camera_logo_ic)
// ─ Room name EditText (max 20)
// ─ Topic EditText (multiline, 92dp, max 100)
// ─ Room lock + password field (6 digits)
// ─ Admin row (next_2_ic)
// ─ Blacklist row (ic_go_jiantou)
// ─ Confirm button (50dp, margin 16h/12b)
// ═══════════════════════════════════════════════════════════════════

class RoomSettingsScreen extends StatefulWidget {
  final String roomId;
  final String initialName;
  final String initialPassword;
  final String? roomAvatarPath;
  final List<Map<String, dynamic>> admins;
  final void Function(String name, String password, String? photoUrl)? onConfirm;
  final bool isModerator;

  const RoomSettingsScreen({
    super.key,
    required this.roomId,
    this.initialName = '',
    this.initialPassword = '',
    this.roomAvatarPath,
    this.admins = const [],
    this.onConfirm,
    this.isModerator = false,
  });

  @override
  State<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends State<RoomSettingsScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _pwdCtrl;
  late final TextEditingController _topicCtrl;
  bool _isLocked = false;
  String? _roomAvatar;
  int _blacklistCount = 0;
  final SupabaseService _firebaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _pwdCtrl = TextEditingController(text: widget.initialPassword);
    _topicCtrl = TextEditingController();
    _isLocked = widget.initialPassword.isNotEmpty;
    _roomAvatar = widget.roomAvatarPath;
    _loadBlacklistCount();
  }

  void _loadBlacklistCount() {
    _firebaseService.getRoomBlockedUids(widget.roomId).then((uids) {
      if (mounted) setState(() => _blacklistCount = uids.length);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pwdCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navH = MediaQuery.of(context).padding.bottom;
    final statusH = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Column(
        children: [
          // ── Header with background image ───────────────────────
          SizedBox(
            height: statusH + 100,
            child: Stack(
              children: [
                R.image(
                  R.roomCreateRoomBg,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.fill,
                ),
                Positioned(
                  top: statusH,
                  left: 0,
                  right: 0,
                  child: _buildAppBar(context),
                ),
              ],
            ),
          ),

          // ── Scrollable content ──────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // ── Room image ─────────────────────────────────
                  _buildRoomImage(),
                  const SizedBox(height: 24),

                  // ── Room name ──────────────────────────────────
                  _buildSectionLabel('Room Name'),
                  const SizedBox(height: 8),
                  _buildNameField(),
                  const SizedBox(height: 24),

                  // ── Topic ──────────────────────────────────────
                  _buildSectionLabel('Topic'),
                  const SizedBox(height: 8),
                  _buildTopicField(),
                  const SizedBox(height: 24),

                  // ── Room lock (owner only) ─────────────────────
                  if (!widget.isModerator) ...[
                    _buildSectionLabel('Lock Room'),
                    const SizedBox(height: 8),
                    _buildLockRow(),
                    const SizedBox(height: 24),
                  ],

                  // ── Admin (owner only) ─────────────────────────
                  if (!widget.isModerator) ...[
                    _buildListRow(
                      icon: R.next2Ic,
                      label: 'Admin',
                      count: widget.admins.length,
                      onTap: () => _showAdminSheet(context),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Blacklist (owner only) ─────────────────────
                  if (!widget.isModerator) ...[
                    _buildListRow(
                      icon: R.icGoJiantou,
                      label: 'Blacklist',
                      count: _blacklistCount,
                      onTap: () => _showBlacklistSheet(context),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Reports ─────────────────────────────────────
                  _buildListRow(
                    icon: R.icGoJiantou,
                    label: 'Reports',
                    count: 0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportsAdminScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // ── Confirm button ─────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, navH + 12),
            child: GestureDetector(
              onTap: () {
                final name = _nameCtrl.text.trim();
                final pwd = _isLocked ? _pwdCtrl.text.trim() : '';
                widget.onConfirm?.call(name, pwd, _roomAvatar);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.giftBtnGradient,
                  borderRadius: BorderRadius.circular(25),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Confirm',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: R.image(
              R.backIc,
              width: 28,
              height: 28,
            ),
          ),
          const SizedBox(width: 8),
          R.image(
            R.roomCreateLabelIc,
            width: 20,
            height: 20,
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Room Settings',
              style: TextStyle(
                fontSize: 24,
                color: Color(0xFF16151A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ───────────────────────────────────────────────
  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF16151A),
      ),
    );
  }

  // ── Room image: 108×108 circle + camera icon ────────────────────
  Widget _buildRoomImage() {
    return GestureDetector(
      onTap: _pickRoomImage,
      child: Center(
        child: SizedBox(
          width: 108,
          height: 108,
          child: Stack(
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFC525),
                    width: 0,
                  ),
                  color: const Color(0xFF1A0F0F),
                ),
                child: ClipOval(
                  child: _roomAvatar != null
                      ? (_roomAvatar!.startsWith('http')
                          ? Image(
                              image: R.cachedImage(_roomAvatar!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                            )
                          : Image.asset(
                              _roomAvatar!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                            ))
                      : _avatarPlaceholder(),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 0,
                child: R.image(
                  R.roomCameraLogoIc,
                  width: 30,
                  height: 30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() => Container(
    color: const Color(0xFF1A0F0F),
    child: const Icon(Icons.image_outlined, color: Colors.white54, size: 40),
  );

  Future<void> _pickRoomImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;
    try {
      final url = await CloudinaryService().uploadImage(File(image.path));
      if (mounted) setState(() => _roomAvatar = url);
    } catch (e) {
      debugPrint('Error uploading room image: $e');
    }
  }

  // ── Room name field ─────────────────────────────────────────────
  Widget _buildNameField() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FB),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      constraints: const BoxConstraints(minHeight: 49),
      child: TextField(
        controller: _nameCtrl,
        style: const TextStyle(fontSize: 13, color: Color(0xFF16151A)),
        maxLength: 20,
        decoration: const InputDecoration(
          hintText: 'Enter room name',
          hintStyle: TextStyle(color: Color(0xFF9BA1B6)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          isDense: true,
          counterText: '',
        ),
      ),
    );
  }

  // ── Topic field (multiline, 92dp, max 100) ──────────────────────
  Widget _buildTopicField() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FB),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 92,
      child: TextField(
        controller: _topicCtrl,
        style: const TextStyle(fontSize: 13, color: Color(0xFF16151A)),
        maxLength: 100,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        expands: true,
        decoration: const InputDecoration(
          hintText: 'Enter topic description',
          hintStyle: TextStyle(color: Color(0xFF9BA1B6)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(top: 12, bottom: 32),
          isDense: true,
          counterText: '',
        ),
      ),
    );
  }

  // ── Lock switch row ─────────────────────────────────────────────
  Widget _buildLockRow() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FB),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      constraints: const BoxConstraints(minHeight: 50),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _pwdCtrl,
              enabled: _isLocked,
              style: const TextStyle(fontSize: 13, color: Color(0xFF16151A)),
              obscureText: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Set room password',
                hintStyle: TextStyle(color: Color(0xFF9BA1B6)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                isDense: true,
                counterText: '',
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _isLocked = !_isLocked;
              if (!_isLocked) _pwdCtrl.clear();
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 47,
              height: 29,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.5),
                color: _isLocked
                    ? const Color(0xFFFFC525)
                    : const Color(0x33000000),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: _isLocked ? 22 : 2,
                    top: 2,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── List row (Admin / Blacklist) ────────────────────────────────
  Widget _buildListRow({
    required String icon,
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF000000),
                ),
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC525).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFFC525),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            R.image(
              R.roomCameraLogoIc,
              width: 30,
              height: 30,
            ),
          ],
        ),
      ),
    );
  }

  // ── Admin sheet ─────────────────────────────────────────────────
  void _showAdminSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF211211),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _UserListSheet(
            title: 'Admins',
            users: widget.admins,
            emptyMessage: 'No admins assigned yet',
            actionLabel: 'Remove Admin',
            onAction: (user) {},
          ),
          Container(height: 0.5, color: const Color(0x1AFFFFFF)),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoomAdminsScreen(roomId: widget.roomId)),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: const Text(
                'عرض الكل',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Blacklist sheet ─────────────────────────────────────────────
  void _showBlacklistSheet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BlacklistScreen(roomId: widget.roomId)),
    );
  }
}

// ─── User list bottom sheet (Admin / Blacklist) ──────────────────
class _UserListSheet extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> users;
  final String emptyMessage;
  final String actionLabel;
  final void Function(Map<String, dynamic> user)? onAction;

  const _UserListSheet({
    required this.title,
    required this.users,
    required this.emptyMessage,
    required this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: const Color(0x1AFFFFFF)),
          Expanded(
            child: users.isEmpty
                ? Center(
                    child: Text(
                      emptyMessage,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white54,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: users.length,
                    separatorBuilder: (_, __) =>
                        Container(height: 0.5, color: const Color(0x1AFFFFFF)),
                    itemBuilder: (_, i) {
                      final u = users[i];
                      return ListTile(
                        leading: ClipOval(
                          child: Image.asset(
                            u['avatar']?.toString() ?? R.avaBoy,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 40,
                              height: 40,
                              color: AppColors.cardBg,
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          u['name']?.toString() ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'ID: ${u['id'] ?? '---'}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                        trailing: GestureDetector(
                          onTap: () {
                            onAction?.call(u);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentRed.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              actionLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFE82323),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
