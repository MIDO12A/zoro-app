import 'package:flutter/material.dart';
import '../../../config/r.dart';
import '../../../config/app_colors.dart';

// fragment_room_info.xml
// ConstraintLayout, wrap_content
//  ├─ StatusBarHeightImageView  (status_bar_height)
//  ├─ cl_room_info   width=70%, paddingStart=14, paddingVertical=5
//  │   ├─ iv_room_avatar  40×40 corner=8dp  start/top
//  │   ├─ tv_room_name    13sp #fff  marginStart=5 marginTop=4 maxLines=1  end-ellipsis
//  │   ├─ tv_room_id      10sp #b2fff  bottom-align with avatar, start of tv_room_name
//  │   ├─ iv_room_lock    12×12 visibility=gone  marginStart=2  end of tv_room_id
//  │   └─ tv_room_hot_value 10sp #b2fff  drawableStart=room_hot_logo_ic  marginStart=2
//  ├─ cl_game_them   match_parent height=32  bg=#1affffff  paddingH=14
//  │   ├─ iv_game_icon   24×24 centerCrop  marginStart=5
//  │   ├─ tv_game_type   9sp bold white  paddingH=6 paddingV=2  marginStart=5
//  │   ├─ tv_game_desc   0dp #80fff  marginStart=5  fills rest → end of cl_online_user
//  │   └─ cl_online_user  bg=room_online_info_bg  h=24  paddingStart=4
//  │       ├─ flip_avatar  (overlapping avatars, marginEnd=4)
//  │       └─ tv_online_num  11sp white  drawableEnd=next_white_ic  marginEnd=6
//  └─ iv_close  24×24  src=room_exit_ic  marginEnd=13  constrained bottom=parent top=parent

class RoomHeader extends StatelessWidget {
  final String? roomName;
  final String? roomId;
  final String? hostAvatar;
  final bool isLocked;
  final String? hotValue;
  final String? gameDesc;
  final String? onlineCount;
  final List<String> onlineAvatars;
  final bool isFollowed;
  final VoidCallback onExit;
  final VoidCallback? onInfoTap;
  final VoidCallback? onOnlineTap;
  final VoidCallback? onGameTap;
  final VoidCallback? onFollow;
  const RoomHeader({
    super.key,
    this.roomName,
    this.roomId,
    this.hostAvatar,
    this.isLocked = false,
    this.hotValue,
    this.gameDesc,
    this.onlineCount,
    this.onlineAvatars = const [],
    this.isFollowed = false,
    required this.onExit,
    this.onInfoTap,
    this.onOnlineTap,
    this.onGameTap,
    this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    final statusH = MediaQuery.of(context).padding.top;
    final sw = MediaQuery.of(context).size.width;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // StatusBarHeightImageView
        SizedBox(height: statusH),

        // cl_room_info row + iv_close overlay
        SizedBox(
          height: 50,
          child: Stack(
            children: [
              // cl_room_info: 70% width, paddingStart=14, paddingVertical=5
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: sw * 0.70,
                child: GestureDetector(
                  onTap: onInfoTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 5, 0, 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // iv_room_avatar: 40×40 corner=8dp + car SVGA overlay
                        SizedBox(
                          width: 40,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: R.loadImage(
                                  hostAvatar ?? R.avaBoy,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // tv_room_name: 13sp white, marginTop=4
                              Text(
                                roomName ?? 'Room',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFFFFFFF),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              // tv_room_id + iv_room_lock + tv_room_hot_value
                              Row(
                                children: [
                                  Text(
                                    'ID: ${roomId ?? '------'}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xB2FFFFFF),
                                    ),
                                  ),
                                  if (isLocked) ...[
                                    const SizedBox(width: 2),
                                    R.image(
                                      R.roomLockStateIc,
                                      width: 12,
                                      height: 12,
                                    ),
                                  ],
                                  const SizedBox(width: 2),
                                  // tv_room_hot_value: drawableStart=room_hot_logo_ic
                                  R.image(
                                    R.roomHotLogoIc,
                                    width: 10,
                                    height: 10,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    hotValue ?? '0',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xB2FFFFFF),
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
                ),
              ),

              // Follow button
              Positioned(
                right: 48,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: onFollow,
                  child: Center(
                    child: Icon(
                      isFollowed
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: isFollowed ? Colors.red : Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // iv_close: 24×24, marginEnd=13, centered vertically
              Positioned(
                right: 13,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: onExit,
                  child: Center(
                    child: R.image(
                      R.roomExitIc,
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // cl_game_them: match_parent h=32 bg=#1affffff paddingH=14
        GestureDetector(
          onTap: onGameTap,
          child: Container(
            height: 32,
            color: const Color(0x1AFFFFFF),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                // iv_game_icon: 24×24, marginStart=5
                const SizedBox(width: 5),
                R.image(
                  R.roomGameIc,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 5),
                // tv_game_type: 9sp bold white, paddingH=6 paddingV=2
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: const Text(
                    'GAME',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                // tv_game_desc: 0dp fills rest, 10sp #80fff
                Expanded(
                  child: Text(
                    gameDesc ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0x80FFFFFF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // cl_online_user: bg=room_online_info_bg, h=24, paddingStart=4
                GestureDetector(
                  onTap: onOnlineTap,
                  child: Container(
                    height: 24,
                    padding: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(R.roomOnlineInfoBg),
                        fit: BoxFit.fill,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // flip_avatar: overlapping 16dp circles
                        _OverlapAvatars(
                          avatars: onlineAvatars.isEmpty
                              ? [R.avaBoy, R.avaGirl]
                              : onlineAvatars,
                        ),
                        const SizedBox(width: 2),
                        // tv_online_num: 11sp white, drawableEnd=next_white_ic, marginEnd=6
                        Text(
                          onlineCount ?? '0',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 2),
                        R.image(
                          R.nextWhiteIc,
                          width: 10,
                          height: 10,
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Overlapping small avatars (OverlappingAvatarView)
class _OverlapAvatars extends StatelessWidget {
  final List<String> avatars;
  const _OverlapAvatars({required this.avatars});

  @override
  Widget build(BuildContext context) {
    const double size = 16;
    const double step = 10;
    final count = avatars.length.clamp(0, 3);
    return SizedBox(
      width: size + (count - 1) * step,
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < count; i++)
            Positioned(
              left: i * step,
              child: ClipOval(
                child: Image.asset(
                  avatars[i],
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: size,
                    height: size,
                    decoration: const BoxDecoration(
                      color: AppColors.cardBg,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
