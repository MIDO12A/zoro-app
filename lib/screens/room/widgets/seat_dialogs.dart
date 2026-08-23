import 'package:flutter/material.dart';
import '../models/seat_model.dart';

// ═══════════════════════════════════════════════════════════════════
// Seat action bottom sheets
//
// layout_seat_opretion_empty.xml   → showEmptySeatDialog
// layout_seat_opretion_hasuser.xml → showOccupiedSeatDialog
// ═══════════════════════════════════════════════════════════════════

class SeatDialogs {
  // ──────────────────────────────────────────────────────────────────
  // showEmptySeatDialog  — layout_seat_opretion_empty.xml
  //   idSeatActionTakeMic
  //   idSeatActionInviteSeat
  //   idSeatActionLockSeat
  //   idSeatActionMicStatus
  //   [separator 10dp]
  //   idSeatActionCancel
  // ──────────────────────────────────────────────────────────────────
  static Future<void> showEmptySeatDialog(
    BuildContext context, {
    required int seatIndex,
    required bool isOwnerOrModerator,
    required bool isLocked,
    required bool isMuted,
    VoidCallback? onTakeMic,
    VoidCallback? onInviteToMic,
    void Function(bool locked)? onToggleLock,
    void Function(bool muted)? onToggleMic,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmptySeatSheet(
        seatIndex: seatIndex,
        isOwnerOrModerator: isOwnerOrModerator,
        isLocked: isLocked,
        isMuted: isMuted,
        onTakeMic: onTakeMic,
        onInviteToMic: onInviteToMic,
        onToggleLock: onToggleLock,
        onToggleMic: onToggleMic,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // showOccupiedSeatDialog  — layout_seat_opretion_hasuser.xml
  //   idSeatActionUserDetail
  //   idSeatActionKickOffMic
  //   idSeatActionLockUnLockMic
  //   idSeatActionSetAdminOrRemove
  //   idSeatActionComments
  //   idSeatActionBlackOrUnBlackUser
  //   idSeatActionKickOutFromRoom
  //   [separator]
  //   Cancel
  // ──────────────────────────────────────────────────────────────────
  static Future<void> showOccupiedSeatDialog(
    BuildContext context, {
    required UserModel user,
    required bool isOwner,
    required bool isOwnerOrModerator,
    required bool isMuted,
    required bool isAdmin,
    required bool isBlacked,
    VoidCallback? onUserDetail,
    VoidCallback? onKickOffMic,
    void Function(bool muted)? onToggleMicLock,
    void Function(bool admin)? onSetAdmin,
    void Function(bool enabled)? onToggleComments,
    void Function(bool blacked)? onToggleBlack,
    VoidCallback? onKickOutFromRoom,
    VoidCallback? onPrivateMessage,
    VoidCallback? onGift,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OccupiedSeatSheet(
        user: user,
        isOwner: isOwner,
        isOwnerOrModerator: isOwnerOrModerator,
        isMuted: isMuted,
        isAdmin: isAdmin,
        isBlacked: isBlacked,
        onUserDetail: onUserDetail,
        onKickOffMic: onKickOffMic,
        onToggleMicLock: onToggleMicLock,
        onSetAdmin: onSetAdmin,
        onToggleComments: onToggleComments,
        onToggleBlack: onToggleBlack,
        onKickOutFromRoom: onKickOutFromRoom,
        onPrivateMessage: onPrivateMessage,
        onGift: onGift,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Empty seat sheet
// ─────────────────────────────────────────────────────────────────
class _EmptySeatSheet extends StatelessWidget {
  final int seatIndex;
  final bool isOwnerOrModerator;
  final bool isLocked;
  final bool isMuted;
  final VoidCallback? onTakeMic;
  final VoidCallback? onInviteToMic;
  final void Function(bool locked)? onToggleLock;
  final void Function(bool muted)? onToggleMic;

  const _EmptySeatSheet({
    required this.seatIndex,
    required this.isOwnerOrModerator,
    required this.isLocked,
    required this.isMuted,
    this.onTakeMic,
    this.onInviteToMic,
    this.onToggleLock,
    this.onToggleMic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          _DragHandle(),
          // idSeatActionTakeMic — always visible
          _SheetItem(
            label: 'Take Mic',
            onTap: () {
              Navigator.pop(context);
              onTakeMic?.call();
            },
          ),
          _Divider(),
          // idSeatActionInviteSeat — owner/moderator only
          if (isOwnerOrModerator) ...[
            _SheetItem(
              label: 'Invite to Mic',
              onTap: () {
                Navigator.pop(context);
                onInviteToMic?.call();
              },
            ),
            _Divider(),
            // idSeatActionLockSeat
            _SheetItem(
              label: isLocked ? 'Unlock Seat' : 'Lock Seat',
              onTap: () {
                Navigator.pop(context);
                onToggleLock?.call(!isLocked);
              },
            ),
            _Divider(),
            // idSeatActionMicStatus
            _SheetItem(
              label: isMuted ? 'Unmute Mic' : 'Mute Mic',
              onTap: () {
                Navigator.pop(context);
                onToggleMic?.call(!isMuted);
              },
            ),
            _Divider(),
          ],
          // Separator 10dp
          Container(height: 10, color: const Color(0x0D9BA1B6)),
          // idSeatActionCancel
          _SheetItem(
            label: 'Cancel',
            color: const Color(0xFF666666),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Occupied seat sheet
// ─────────────────────────────────────────────────────────────────
class _OccupiedSeatSheet extends StatelessWidget {
  final UserModel user;
  final bool isOwner;
  final bool isOwnerOrModerator;
  final bool isMuted;
  final bool isAdmin;
  final bool isBlacked;
  final VoidCallback? onUserDetail;
  final VoidCallback? onKickOffMic;
  final void Function(bool muted)? onToggleMicLock;
  final void Function(bool admin)? onSetAdmin;
  final void Function(bool enabled)? onToggleComments;
  final void Function(bool blacked)? onToggleBlack;
  final VoidCallback? onKickOutFromRoom;
  final VoidCallback? onPrivateMessage;
  final VoidCallback? onGift;

  const _OccupiedSeatSheet({
    required this.user,
    required this.isOwner,
    required this.isOwnerOrModerator,
    required this.isMuted,
    required this.isAdmin,
    required this.isBlacked,
    this.onUserDetail,
    this.onKickOffMic,
    this.onToggleMicLock,
    this.onSetAdmin,
    this.onToggleComments,
    this.onToggleBlack,
    this.onKickOutFromRoom,
    this.onPrivateMessage,
    this.onGift,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DragHandle(),
          // User name header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              user.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16151A),
              ),
            ),
          ),
          _Divider(),
          // idSeatActionUserDetail
          _SheetItem(
            label: 'User Detail',
            onTap: () {
              Navigator.pop(context);
              onUserDetail?.call();
            },
          ),
          _Divider(),
          // Owner/moderator actions
          if (isOwnerOrModerator) ...[
            // idSeatActionKickOffMic
            _SheetItem(
              label: 'Kick Off Mic',
              onTap: () {
                Navigator.pop(context);
                onKickOffMic?.call();
              },
            ),
            _Divider(),
            // idSeatActionLockUnLockMic
            _SheetItem(
              label: isMuted ? 'Unmute Mic' : 'Mute Mic',
              onTap: () {
                Navigator.pop(context);
                onToggleMicLock?.call(!isMuted);
              },
            ),
            _Divider(),
            // idSeatActionKickOutFromRoom — owner/moderator
            _SheetItem(
              label: 'Kick Out From Room',
              color: const Color(0xFFE82323),
              onTap: () {
                Navigator.pop(context);
                onKickOutFromRoom?.call();
              },
            ),
            _Divider(),
          ],
          // Owner-only actions
          if (isOwner) ...[
            // idSeatActionSetAdminOrRemove
            _SheetItem(
              label: isAdmin ? 'Remove Admin' : 'Set as Admin',
              onTap: () {
                Navigator.pop(context);
                onSetAdmin?.call(!isAdmin);
              },
            ),
            _Divider(),
            // idSeatActionComments
            _SheetItem(
              label: 'Allow Comments',
              onTap: () {
                Navigator.pop(context);
                onToggleComments?.call(true);
              },
            ),
            _Divider(),
            // idSeatActionBlackOrUnBlackUser
            _SheetItem(
              label: isBlacked ? 'Unblack User' : 'Black User',
              color: isBlacked ? Colors.black87 : const Color(0xFFE82323),
              onTap: () {
                Navigator.pop(context);
                onToggleBlack?.call(!isBlacked);
              },
            ),
            _Divider(),
          ],
          if (!isOwnerOrModerator) ...[
            // Regular user options: private message, gift
            _SheetItem(
              label: 'Private Message',
              onTap: () {
                Navigator.pop(context);
                onPrivateMessage?.call();
              },
            ),
            _Divider(),
            _SheetItem(
              label: 'Send Gift',
              onTap: () {
                Navigator.pop(context);
                onGift?.call();
              },
            ),
            _Divider(),
          ],
          // Separator
          Container(height: 10, color: const Color(0x0D9BA1B6)),
          // Cancel
          _SheetItem(
            label: 'Cancel',
            color: const Color(0xFF666666),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
      ),
    );
  }
}

// ─── Shared widgets ──────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0x1A000000),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SheetItem({
    required this.label,
    this.color = Colors.black87,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            label,
            style: TextStyle(fontSize: 16, color: color),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 0.6, color: const Color(0x1A000000));
  }
}
