import 'package:flutter/material.dart';
import '../../../config/r.dart';

// fragment_room_bottom_set2.xml
// LinearLayoutCompat vertical
//   bg=shape_room_chat_bg (#f51d1111, topLeft/topRight=12dp)
//   paddingTop=14, paddingBottom=20
//   tv "Function" 15sp white  marginH=16
//   recyclerview_function  match_parent wrap_content
//   tv "Effect"   15sp white  marginH=16 marginTop=30
//   recyclerview_effect   match_parent wrap_content
//
// adapter_room_function_item.xml per item:
//   48×48 icon + 10sp white label below, marginTop=10

class FunctionPanel extends StatelessWidget {
  final VoidCallback? onClose;
  final void Function(String label)? onItemTap;
  final bool isOwner;
  final bool isModerator;

  const FunctionPanel({
    super.key,
    this.onClose,
    this.onItemTap,
    this.isOwner = false,
    this.isModerator = false,
  });

  List<Map<String, String>> get _functions {
    final items = <Map<String, String>>[
      {'icon': R.roomSetVolumeIc, 'label': 'Volume'},
      {'icon': R.roomSetSetIc, 'label': 'Settings'},
    ];
    if (isOwner) {
      items.add({'icon': R.roomSetSeatStyle, 'label': 'Seat Style'});
    }
    items.addAll([
      {'icon': R.roomSetReportIc, 'label': 'Report'},
      {'icon': R.roomSetMixerIc, 'label': 'Mixer'},
      {'icon': R.roomSetGiftIc, 'label': 'Gift'},
      {'icon': R.roomSetEffectIc, 'label': 'Effect'},
      {'icon': R.roomSetMusicIc, 'label': 'Music'},
      {'icon': '', 'label': 'Notifications'},
      {'icon': '', 'label': 'Rankings'},
      {'icon': '', 'label': 'Share'},
    ]);
    return items;
  }

  static const List<Map<String, String>> _effects = [
    {'icon': R.roomSetEffectIc, 'label': 'Effect 1'},
    {'icon': R.roomSetMixerIc, 'label': 'Mixer'},
    {'icon': R.roomSetVolumeIc, 'label': 'Bass'},
    {'icon': R.roomSetMusicIc, 'label': 'Echo'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF51D1111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: const EdgeInsets.only(top: 14, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Function',
              style: TextStyle(fontSize: 15, color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          _buildRow(_functions),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 30, 16, 0),
            child: Text(
              'Effect',
              style: TextStyle(fontSize: 15, color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          _buildRow(_effects),
        ],
      ),
    );
  }

  Widget _buildRow(List<Map<String, String>> items) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onItemTap?.call(items[i]['label']!),
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                items[i]['icon']!.isNotEmpty
                    ? Image.asset(
                        items[i]['icon']!,
                        width: 48,
                        height: 48,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.settings, color: Colors.white70, size: 22),
                        ),
                      )
                    : const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.notifications, color: Colors.white70, size: 22),
                      ),
                const SizedBox(height: 6),
                Text(
                  items[i]['label']!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xB3FFFFFF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
