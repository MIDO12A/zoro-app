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
  final SeatStyle seatStyle;

  const SeatArea({
    super.key,
    required this.seats,
    required this.onSeatTap,
    this.seatEmojis,
    this.moderators,
    this.hostUid,
    this.seatStyle = SeatStyle.classic,
  });

  @override
  Widget build(BuildContext context) {
    if (seatStyle == SeatStyle.circle && seats.length == 10) {
      return _buildGameLayout(context);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: _buildGrid(),
    );
  }

  Widget _buildGameLayout(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 360,
        height: 380,
        child: Stack(
          children: [
            _positionSeat(0, 180, 175, isCaptain: true),
            _positionSeat(2, 180, 42),
            _positionSeat(1, 98, 70),
            _positionSeat(3, 262, 70),
            _positionSeat(9, 50, 150),
            _positionSeat(4, 310, 150),
            _positionSeat(8, 50, 245),
            _positionSeat(5, 310, 245),
            _positionSeat(7, 120, 305),
            _positionSeat(6, 240, 305),
          ],
        ),
      ),
    );
  }

  Widget _positionSeat(int idx, double x, double y, {bool isCaptain = false}) {
    if (idx >= seats.length) return const SizedBox();
    final double width = isCaptain ? 86 : 76;
    final double height = isCaptain ? 98 : 88;

    return Positioned(
      left: x - width / 2,
      top: y - height / 2,
      child: GestureDetector(
        onTap: () => onSeatTap(idx),
        child: _NormalSeat(
          seat: seats[idx],
          emoji: seatEmojis?[idx],
          isModerator: seats[idx].user != null
              ? moderators?.contains(seats[idx].user!.id) ?? false
              : false,
          seatStyle: seatStyle,
          isCaptain: isCaptain,
        ),
      ),
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
                      seatStyle: seatStyle,
                      isCaptain: false,
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

class _NormalSeat extends StatelessWidget {
  final SeatModel seat;
  final String? emoji;
  final bool isModerator;
  final SeatStyle seatStyle;
  final bool isCaptain;

  const _NormalSeat({
    required this.seat,
    this.emoji,
    this.isModerator = false,
    this.seatStyle = SeatStyle.classic,
    this.isCaptain = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasUser = seat.user != null;
    final user = seat.user;
    final name = user?.name ?? '';
    final charm = user?.charm;
    final avatar = user?.avatar;
    final hasFrame = seat.hasFrame;
    final frameAsset = seat.frameAsset ?? R.superAdminFrame;

    Widget child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 76,
          height: 88,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 6,
                left: 6,
                child: _buildAvatarPart(hasUser, avatar, hasFrame, frameAsset),
              ),
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
                  hasUser ? name : (isCaptain ? 'Captain' : '${seat.index}'),
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
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
                  R.image(R.roomMicCharmMaleIc, width: 9, height: 9),
                  const SizedBox(width: 1),
                  Text(
                    charm,
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    if (isCaptain) {
      child = Transform.scale(
        scale: 1.15,
        child: child,
      );
    }
    return child;
  }

  Widget _buildAvatarPart(bool hasUser, String? avatar, bool hasFrame, String frameAsset) {
    const double size = 52.0;
    const double borderSize = 64.0;

    if (!hasUser) {
      String emptyIcon = R.roomMicSeatDefaultIc;
      if (seatStyle == SeatStyle.heart) {
        emptyIcon = R.mipmap('room_mic_seat_default_vip_2_ic');
      }
      return Center(
        child: SizedBox(
          width: borderSize,
          height: borderSize,
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: seat.isLocked
                  ? R.image(R.roomMicSeatLockIc, fit: BoxFit.cover)
                  : Image.asset(
                      emptyIcon,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.chair, color: Colors.white54, size: size * 0.5),
                    ),
            ),
          ),
        ),
      );
    }

    final avatarWidget = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: avatar != null ? _loadAvatar(avatar, size) : _emptyCircle(size),
      ),
    );

    if (hasFrame) {
      return Stack(
        alignment: Alignment.center,
        children: [
          avatarWidget,
          SvgaFrame(svgaPath: frameAsset, size: borderSize),
        ],
      );
    }

    if (seatStyle == SeatStyle.circle) {
      // Game style: thick metallic silver ring
      return Container(
        width: borderSize,
        height: borderSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFBDC3C7),
              Color(0xFF7F8C8D),
              Color(0xFFECEFF1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: ClipOval(
          child: SizedBox(
            width: borderSize - 8.0,
            height: borderSize - 8.0,
            child: avatarWidget,
          ),
        ),
      );
    } else if (seatStyle == SeatStyle.heart) {
      // VIP style: thick metallic gold ring
      return Container(
        width: borderSize,
        height: borderSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF275),
              Color(0xFFD4AF37),
              Color(0xFF8C6200),
              Color(0xFFFFF9C4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: ClipOval(
          child: SizedBox(
            width: borderSize - 8.0,
            height: borderSize - 8.0,
            child: avatarWidget,
          ),
        ),
      );
    }

    // Classic style: thin gold border (original)
    return SizedBox(
      width: borderSize,
      height: borderSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          avatarWidget,
          Container(
            width: borderSize,
            height: borderSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.goldLight.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
