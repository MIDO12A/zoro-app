import 'package:flutter/material.dart';
import '../../../config/r.dart';
import '../../../config/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════
// SeatStylePanel — room_fragment_seat_style.xml
//
// Title "Seat Style" + close button
// RadioGroup horizontal: Game / Classic / VIP
//   Game    → rb_seat_style_game    icon=room_mic_seat_style_default_ic
//   Classic → rb_seat_style_normal  icon=room_mic_seat_style_default_ic
//   VIP     → rb_seat_style_vip     icon=room_mic_seat_default_vip_2_ic
//
// Horizontal scrollable list of seat count options (10, 12, 15, 20)
//   Each item: room_bg_seat_pre (104×160) + count-style image on top + count number
//   Available images per style:
//     Classic: room_bg_classic_seat_10/12/15/20
//     VIP:     room_bg_vip_seat_10/12/15/20
//     Game:    room_bg_game_seat_10 (only 10)
//
// Confirm button
// ═══════════════════════════════════════════════════════════════════

enum SeatStyle { game, classic, vip }

class SeatStylePanel extends StatefulWidget {
  final SeatStyle initialStyle;
  final int initialSeatCount;
  final void Function(SeatStyle style, int count)? onConfirm;
  final VoidCallback? onClose;

  const SeatStylePanel({
    super.key,
    this.initialStyle = SeatStyle.classic,
    this.initialSeatCount = 10,
    this.onConfirm,
    this.onClose,
  });

  @override
  State<SeatStylePanel> createState() => _SeatStylePanelState();
}

class _SeatStylePanelState extends State<SeatStylePanel> {
  late SeatStyle _style;
  late int _count;

  static const _counts = [5, 8, 10, 12, 15, 20];

  @override
  void initState() {
    super.initState();
    _style = widget.initialStyle;
    _count = widget.initialSeatCount;
  }

  List<int> get _availableCounts {
    if (_style == SeatStyle.game) return [10];
    return _counts;
  }

  String _styleImage(SeatStyle style, int count) {
    switch (style) {
      case SeatStyle.classic:
        return R.mipmap('room_bg_classic_seat_$count');
      case SeatStyle.vip:
        return R.mipmap('room_bg_vip_seat_$count');
      case SeatStyle.game:
        return R.mipmap('room_bg_game_seat_10');
    }
  }

  String _styleIcon(SeatStyle style) {
    if (style == SeatStyle.vip) {
      return R.mipmap('room_mic_seat_default_vip_2_ic');
    }
    return R.mipmap('room_mic_seat_style_default_ic');
  }

  String _styleLabel(SeatStyle style) {
    switch (style) {
      case SeatStyle.game:
        return 'Game';
      case SeatStyle.classic:
        return 'Classic';
      case SeatStyle.vip:
        return 'VIP';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF211211),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Seat Style',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onClose ?? () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Divider
          Container(height: 0.5, color: const Color(0x1AFFFFFF)),
          const SizedBox(height: 16),

          // ── RadioGroup: Game / Classic / VIP ─────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: SeatStyle.values.map((s) {
              final selected = _style == s;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _style = s;
                    // Reset count if not available in new style
                    if (!_availableCounts.contains(_count)) {
                      _count = _availableCounts.first;
                    }
                  });
                },
                child: _StyleRadioItem(
                  label: _styleLabel(s),
                  iconPath: _styleIcon(s),
                  selected: selected,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── Seat count horizontal scroller ───────────────────
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _availableCounts.length,
              itemBuilder: (_, i) {
                final count = _availableCounts[i];
                final selected = _count == count;
                return GestureDetector(
                  onTap: () => setState(() => _count = count),
                  child: _CountItem(
                    count: count,
                    imagePath: _styleImage(_style, count),
                    selected: selected,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // ── Confirm button ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () {
                widget.onConfirm?.call(_style, _count);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.giftBtnGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Confirm',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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

// ── Style radio button item ─────────────────────────────────────
class _StyleRadioItem extends StatelessWidget {
  final String label;
  final String iconPath;
  final bool selected;

  const _StyleRadioItem({
    required this.label,
    required this.iconPath,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.goldLight : Colors.transparent,
              width: 2,
            ),
            color: selected
                ? AppColors.goldLight.withValues(alpha: 0.12)
                : AppColors.cardBg,
          ),
          child: Center(
            child: Image.asset(
              iconPath,
              width: 36,
              height: 36,
              errorBuilder: (_, __, ___) => Icon(
                Icons.chair,
                color: selected ? AppColors.goldLight : Colors.white54,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? AppColors.goldLight : Colors.white70,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        // Radio dot indicator
        const SizedBox(height: 4),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.goldLight : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.goldLight : Colors.white38,
              width: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Seat count item ─────────────────────────────────────────────
class _CountItem extends StatelessWidget {
  final int count;
  final String imagePath;
  final bool selected;

  const _CountItem({
    required this.count,
    required this.imagePath,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.goldLight : Colors.transparent,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            // room_bg_seat_pre: outer frame 104×160
            Image.asset(
              R.roomBgSeatPre,
              width: 104,
              height: 160,
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) =>
                  Container(width: 104, height: 160, color: AppColors.cardBg),
            ),
            // Style-specific image on top
            Positioned.fill(
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
            // Seat count label at bottom
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Text(
                '$count seats',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? AppColors.goldLight : Colors.white,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ),
            // Selection overlay
            if (selected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.goldLight.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    color: AppColors.goldLight.withValues(alpha: 0.08),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
