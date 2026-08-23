import 'package:flutter/material.dart';
import '../../../config/r.dart';
import '../../../config/app_colors.dart';

// fragment_room_bottom_operate.xml
// ConstraintLayout wrap_content
//   iv_gift      48×48  marginBottom=15  center H+V anchor for others
//   iv_chat      32×32  marginStart=14   same V center as iv_gift
//   iv_emoj      32×32  marginStart=10   right of iv_chat
//   iv_mic_state 32×32  marginStart=10   right of iv_emoj
//   iv_function  32×32  marginEnd=14     end of parent
//   iv_msg       32×32  marginEnd=10     left of iv_function
//   tv_msg_count wrap    marginTop=-4 marginStart=18 from iv_msg  (badge)
//   iv_music     32×32  marginEnd=10     left of iv_msg
class BottomBar extends StatelessWidget {
  final bool isMicOn;
  final int msgCount;
  final VoidCallback? onChat;
  final VoidCallback? onEmoj;
  final VoidCallback? onMic;
  final VoidCallback? onGift;
  final VoidCallback? onMusic;
  final VoidCallback? onMsg;
  final VoidCallback? onFunction;

  const BottomBar({
    super.key,
    this.isMicOn = true,
    this.msgCount = 0,
    this.onChat,
    this.onEmoj,
    this.onMic,
    this.onGift,
    this.onMusic,
    this.onMsg,
    this.onFunction,
  });

  @override
  Widget build(BuildContext context) {
    // Total height = 48(gift) + 15(marginBottom) = 63, icons centered on gift
    return SizedBox(
      height: 63,
      child: Stack(
        children: [
          // iv_gift: 48×48, center H, marginBottom=15
          Positioned(
            left: 0,
            right: 0,
            bottom: 15,
            child: Center(
              child: GestureDetector(
                onTap: onGift,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.giftBtnGradient,
                  ),
                  child: Center(
                    child: R.image(
                      R.roomGiftIc,
                      width: 26,
                      height: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Left row: chat(14) + emoj(10) + mic(10)  — centered on gift center=15+24=39 from bottom
          Positioned(
            left: 0,
            bottom: 15,
            child: SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 14),
                  _Btn(asset: R.roomChatIc, size: 32, onTap: onChat),
                  const SizedBox(width: 10),
                  _Btn(asset: R.roomEmojIc, size: 32, onTap: onEmoj),
                  const SizedBox(width: 10),
                  _Btn(
                    asset: isMicOn ? R.roomMicphoneIc : R.roomMicphoneCloseIc,
                    size: 32,
                    onTap: onMic,
                  ),
                ],
              ),
            ),
          ),
          // Right row: music(10) + msg+badge(10) + function(14)  — same center
          Positioned(
            right: 0,
            bottom: 15,
            child: SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Btn(asset: R.roomSetMusicIc, size: 32, onTap: onMusic),
                  const SizedBox(width: 10),
                  // iv_msg + tv_msg_count badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _Btn(asset: R.roomMsgIc, size: 32, onTap: onMsg),
                      if (msgCount > 0)
                        Positioned(
                          top: -4,
                          left: 18,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 17,
                              minHeight: 10,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE82323),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '$msgCount',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  _Btn(asset: R.roomFunctionIc, size: 32, onTap: onFunction),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String asset;
  final double size;
  final VoidCallback? onTap;
  const _Btn({required this.asset, required this.size, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: R.image(
        asset,
        width: size,
        height: size,
      ),
    );
  }
}
