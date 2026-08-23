import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../config/r.dart';
import '../../../config/app_colors.dart';
import '../models/seat_model.dart';
import 'svga_frame.dart';

// ═══════════════════════════════════════════════════════════════════
// SeatArea — fragment_mic_seat.xml
//   seat 0 (owner) → adapter_mic_owner_item.xml  مركزي
//   seats 1-19     → adapter_mic_normal_item.xml  5 في كل صف
// ═══════════════════════════════════════════════════════════════════

Widget _loadAvatar(String? avatar, double size) {
  if (avatar == null || avatar.isEmpty) return _emptyCircle(size);
  if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
    return Image(
      image: R.cachedImage(avatar),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _emptyCircle(size),
    );
  }
  return Image.asset(
    avatar,
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => _emptyCircle(size),
  );
}

Widget _emptyCircle(double s) => Container(
  width: s,
  height: s,
  decoration: const BoxDecoration(
    shape: BoxShape.circle,
    color: Color(0x1AFFFFFF),
  ),
  child: Icon(Icons.person, size: s * 0.45, color: Colors.white38),
);

class SeatArea extends StatelessWidget {
  final List<SeatModel> seats;
  final void Function(int index) onSeatTap;
  final Map<int, String>? seatEmojis;
  final Set<String>? moderators;
  final String? hostUid;

  const SeatArea({
    super.key,
    required this.seats,
    required this.onSeatTap,
    this.seatEmojis,
    this.moderators,
    this.hostUid,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: _buildGrid(),
    );
  }

  Widget _buildGrid() {
    const seatsPerRow = 5;
    final items = seats;
    final rows = <Widget>[];

    for (int i = 0; i < items.length; i += seatsPerRow) {
      final end = math.min(i + seatsPerRow, items.length);
      final rowItems = items.sublist(i, end);

      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (int j = 0; j < rowItems.length; j++)
              Expanded(
                child: Center(
                    child: GestureDetector(
                    onTap: () => onSeatTap(i + j),
                    child: _NormalSeat(
                      seat: rowItems[j],
                      emoji: seatEmojis?[i + j],
                      isModerator: rowItems[j].user != null
                          ? moderators?.contains(rowItems[j].user!.id) ?? false
                          : false,
                    ),
                  ),
                ),
              ),
            for (int k = rowItems.length; k < seatsPerRow; k++)
              const Expanded(child: SizedBox()),
          ],
        ),
      );

      if (end < items.length) rows.add(const SizedBox(height: 6));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

// ─────────────────────────────────────────────────────────────────
// adapter_mic_normal_item.xml — مقاعد عادية (5 في الصف)
//   svga_speaker_wave : 70×70
//   iv_avatar         : 48×48 marginTop=15
//   svga_avatar_header: 60×60  ← SVGA frame
//   iv_mute           : 16×16
//   tv_name           : 12sp
//   tv_charm          : 10sp
// ─────────────────────────────────────────────────────────────────
class _NormalSeat extends StatelessWidget {
  final SeatModel seat;
  final String? emoji;
  final bool isModerator;
  const _NormalSeat({required this.seat, this.emoji, this.isModerator = false});

  @override
  Widget build(BuildContext context) {
    final hasUser = seat.user != null;
    final user = seat.user;
    final name = user?.name ?? '';
    final charm = user?.charm;
    final avatar = user?.avatar;
    final hasFrame = seat.hasFrame;
    final frameAsset = seat.frameAsset ?? R.superAdminFrame;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 76,
          height: 88,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // svga_speaker_wave: around avatar
              if (hasUser)
                Positioned(
                  top: 2,
                  left: 0,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.goldLight.withValues(alpha: 0.12),
                        width: 4,
                      ),
                    ),
                  ),
                ),

              // iv_avatar (photo behind frame)
              Positioned(
                top: 8,
                left: (76 - 56) / 2,
                child: ClipOval(
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: _avatarContent(hasUser, avatar),
                  ),
                ),
              ),

              // svga_avatar_header (frame on top of avatar)
              if (hasUser)
                Positioned(
                  top: (76 - 64) / 2 + 1,
                  left: (76 - 64) / 2,
                  child: hasFrame
                      ? SvgaFrame(svgaPath: frameAsset, size: 64)
                      : Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.goldLight.withValues(
                                alpha: 0.45,
                              ),
                              width: 1.5,
                            ),
                          ),
                        ),
                ),

              // Emoji on avatar
              if (emoji != null && emoji!.isNotEmpty && hasUser)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      emoji!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

              // قفل
              if (!hasUser && seat.isLocked)
                Positioned(
                  bottom: 2,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: R.image(
                      R.roomMicSeatLockIc,
                      width: 14,
                      height: 14,
                    ),
                  ),
                ),

              // كتم
              if (hasUser && seat.isMuted)
                Positioned(
                  top: 34,
                  left: 36,
                  child: R.image(
                    R.roomMicSeatMuteIc,
                    width: 16,
                    height: 16,
                  ),
                ),

            ],
          ),
        ),

        // tv_name or seat number
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isModerator)
                Container(
                  margin: const EdgeInsets.only(right: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Text(
                    'M',
                    style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              SizedBox(
                width: isModerator ? 48 : 56,
                child: Text(
                  hasUser ? name : '${seat.index}',
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // tv_charm under name
        if (hasUser && charm != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 1, 4, 1),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  R.image(
                    R.roomMicCharmMaleIc,
                    width: 9,
                    height: 9,
                  ),
                  const SizedBox(width: 1),
                  Text(
                    charm,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _avatarContent(bool hasUser, String? avatar) {
    if (!hasUser) {
      return seat.isLocked
          ? R.image(
              R.roomMicSeatLockIc,
              fit: BoxFit.cover,
            )
          : R.image(
              R.roomMicSeatDefaultIc,
              fit: BoxFit.cover,
            );
    }
    if (avatar != null) {
      return _loadAvatar(avatar, 48);
    }
    return _empty(48);
  }

  Widget _empty(double s) => Container(
    width: s,
    height: s,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0x1AFFFFFF),
    ),
    child: Icon(
      Icons.add,
      size: s * 0.38,
      color: Colors.white.withValues(alpha: 0.5),
    ),
  );
}
