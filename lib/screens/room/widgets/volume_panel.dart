import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════
// VolumePanel — layout_room_volume.xml
//
// SeekBar horizontal (0-100, initial=20)
// ═══════════════════════════════════════════════════════════════════

class VolumePanel extends StatefulWidget {
  final double initialVolume;
  final void Function(double volume)? onVolumeChanged;
  final VoidCallback? onClose;

  const VolumePanel({
    super.key,
    this.initialVolume = 20.0,
    this.onVolumeChanged,
    this.onClose,
  });

  @override
  State<VolumePanel> createState() => _VolumePanelState();
}

class _VolumePanelState extends State<VolumePanel> {
  late double _volume;

  @override
  void initState() {
    super.initState();
    _volume = widget.initialVolume.clamp(0.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF211211),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Volume',
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
          const SizedBox(height: 20),
          // Volume label + value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.volume_mute, color: Colors.white54, size: 20),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.goldLight,
                    inactiveTrackColor: AppColors.cardBg,
                    thumbColor: AppColors.goldLight,
                    overlayColor: AppColors.goldLight.withValues(alpha: 0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: _volume,
                    min: 0,
                    max: 100,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      widget.onVolumeChanged?.call(v);
                    },
                  ),
                ),
              ),
              const Icon(Icons.volume_up, color: Colors.white54, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          // Percentage display
          Text(
            '${_volume.round()}%',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.goldLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
