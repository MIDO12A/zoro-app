import 'package:flutter/material.dart';
import '../../../config/r.dart';
import '../../../config/app_colors.dart';

class BottomBar extends StatelessWidget {
  final bool isMicOn;
  final bool showMic;
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
    this.showMic = true,
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return SizedBox(
      height: 63,
      child: Stack(
        children: [
          // iv_gift: Centered gift button
          Positioned(
            left: 0,
            right: 0,
            bottom: 15,
            child: Center(
              child: GestureDetector(
                onTap: onGift,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: Center(
                    child: R.image(
                      R.roomGiftIc,
                      width: 46,
                      height: 46,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Action Group 1 (chat, emoj, mic): Left in LTR, Right in RTL
          Positioned(
            left: isAr ? null : 0,
            right: isAr ? 0 : null,
            bottom: 15,
            child: SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: isAr
                    ? [
                        if (showMic) ...[
                          _Btn(
                            asset: isMicOn ? R.roomMicphoneIc : R.roomMicphoneCloseIc,
                            size: 32,
                            onTap: onMic,
                          ),
                          const SizedBox(width: 10),
                        ],
                        _Btn(asset: R.roomEmojIc, size: 32, onTap: onEmoj),
                        const SizedBox(width: 10),
                        _Btn(asset: R.roomChatIc, size: 32, onTap: onChat),
                        const SizedBox(width: 14),
                      ]
                    : [
                        const SizedBox(width: 14),
                        _Btn(asset: R.roomChatIc, size: 32, onTap: onChat),
                        const SizedBox(width: 10),
                        _Btn(asset: R.roomEmojIc, size: 32, onTap: onEmoj),
                        if (showMic) ...[
                          const SizedBox(width: 10),
                          _Btn(
                            asset: isMicOn ? R.roomMicphoneIc : R.roomMicphoneCloseIc,
                            size: 32,
                            onTap: onMic,
                          ),
                        ],
                      ],
              ),
            ),
          ),

          // Action Group 2 (music, msg, function): Right in LTR, Left in RTL
          Positioned(
            left: isAr ? 0 : null,
            right: isAr ? null : 0,
            bottom: 15,
            child: SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: isAr
                    ? [
                        const SizedBox(width: 14),
                        _Btn(asset: R.roomFunctionIc, size: 32, onTap: onFunction),
                        const SizedBox(width: 10),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _Btn(asset: R.roomMsgIc, size: 32, onTap: onMsg),
                            if (msgCount > 0)
                              Positioned(
                                top: -4,
                                right: 18,
                                child: _buildBadge(),
                              ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        _Btn(asset: R.roomSetMusicIc, size: 32, onTap: onMusic),
                      ]
                    : [
                        _Btn(asset: R.roomSetMusicIc, size: 32, onTap: onMusic),
                        const SizedBox(width: 10),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _Btn(asset: R.roomMsgIc, size: 32, onTap: onMsg),
                            if (msgCount > 0)
                              Positioned(
                                top: -4,
                                left: 18,
                                child: _buildBadge(),
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

  Widget _buildBadge() {
    return Container(
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
