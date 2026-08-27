import 'package:flutter/material.dart';

class RoomRankBottomSheet extends StatefulWidget {
  const RoomRankBottomSheet({Key? key}) : super(key: key);

  @override
  State<RoomRankBottomSheet> createState() => _RoomRankBottomSheetState();
}

class _RoomRankBottomSheetState extends State<RoomRankBottomSheet> {
  int _mainTabIndex = 0;
  int _subTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth,
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        image: DecorationImage(
          image: AssetImage('assets/mipmap-xxhdpi/room_rank_bg.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Stack(
        children: [
          // Close button
          Positioned(
            top: 30,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
          
          Column(
            children: [
              const SizedBox(height: 70),
              // Main Tabs (الثروة، السحر، باتل)
              _buildMainTabs(),
              const SizedBox(height: 30),
              // Sub Tabs (يوميا، أسبوعيا، تصنيف المجموع)
              _buildSubTabs(),
              const SizedBox(height: 20),
              // Countdown timer
              const Text(
                'العد التنازلي: 02h 39m 09s (GMT+3)',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              // Empty State / Placeholder
              const Icon(
                Icons.emoji_events,
                color: Color(0xFFFFD54F),
                size: 80,
              ),
              const SizedBox(height: 10),
              const Text(
                'لا توجد بيانات حالياً',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildMainTabItem('باتل', 2),
        const SizedBox(width: 40),
        _buildMainTabItem('السحر', 1),
        const SizedBox(width: 40),
        _buildMainTabItem('الثروة', 0),
      ],
    );
  }

  Widget _buildMainTabItem(String title, int index) {
    bool isActive = _mainTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _mainTabIndex = index;
        });
      },
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isActive ? const Color(0xFFFFD54F) : Colors.white,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          if (isActive)
            Container(
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD54F),
                borderRadius: BorderRadius.circular(1.5),
              ),
            )
          else
            const SizedBox(height: 3),
        ],
      ),
    );
  }

  Widget _buildSubTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          _buildSubTabItem('تصنيف المجموع', 2),
          _buildSubTabItem('أسبوعيًا', 1),
          _buildSubTabItem('يوميا', 0),
        ],
      ),
    );
  }

  Widget _buildSubTabItem(String title, int index) {
    bool isActive = _subTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _subTabIndex = index;
          });
        },
        child: Container(
          alignment: Alignment.center,
          decoration: isActive
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD54F), Color(0xFFF57F17)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                )
              : null,
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
