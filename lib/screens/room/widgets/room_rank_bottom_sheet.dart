import 'package:flutter/material.dart';
import '../../../../services/firebase_service.dart';
import '../../../../config/r.dart';

class RoomRankBottomSheet extends StatefulWidget {
  final String roomId;
  const RoomRankBottomSheet({Key? key, required this.roomId}) : super(key: key);

  @override
  State<RoomRankBottomSheet> createState() => _RoomRankBottomSheetState();
}

class _RoomRankBottomSheetState extends State<RoomRankBottomSheet> {
  int _mainTabIndex = 0; // 0 for Wealth, 1 for Magic
  int _subTabIndex = 0; // 0 for Daily, 1 for Weekly, 2 for Monthly

  List<Map<String, dynamic>> _rankings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRankings();
  }

  void _fetchRankings() async {
    setState(() => _isLoading = true);
    final String timeframe = _subTabIndex == 0 ? 'daily' : _subTabIndex == 1 ? 'weekly' : 'monthly';
    final bool isWealth = _mainTabIndex == 0;
    
    try {
      final data = await FirebaseService().getRoomRankings(
        roomId: widget.roomId,
        isWealth: isWealth,
        timeframe: timeframe,
      );
      if (mounted) {
        setState(() {
          _rankings = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rankings = [];
          _isLoading = false;
        });
      }
    }
  }

  void _onMainTabChanged(int index) {
    if (_mainTabIndex != index) {
      setState(() {
        _mainTabIndex = index;
      });
      _fetchRankings();
    }
  }

  void _onSubTabChanged(int index) {
    if (_subTabIndex != index) {
      setState(() {
        _subTabIndex = index;
      });
      _fetchRankings();
    }
  }

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
              // Main Tabs (الثروة، السحر)
              _buildMainTabs(),
              const SizedBox(height: 30),
              // Sub Tabs (يوميا، أسبوعيا، شهريا)
              _buildSubTabs(),
              const SizedBox(height: 20),
              
              Expanded(
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD54F)))
                    : _rankings.isEmpty
                        ? _buildEmptyState()
                        : _buildRankList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.emoji_events, color: Color(0xFFFFD54F), size: 80),
        const SizedBox(height: 10),
        const Text(
          'لا توجد بيانات حالياً',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildRankList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _rankings.length,
      itemBuilder: (context, index) {
        final item = _rankings[index];
        return _buildRankItem(item, index + 1);
      },
    );
  }

  Widget _buildRankItem(Map<String, dynamic> item, int rank) {
    String? frameAsset;
    if (rank == 1) frameAsset = 'assets/mipmap-xxhdpi/rank_1_frame.png';
    else if (rank == 2) frameAsset = 'assets/mipmap-xxhdpi/rank_2_frame.png';
    else if (rank == 3) frameAsset = 'assets/mipmap-xxhdpi/rank_3_frame.png';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Rank Number
          SizedBox(
            width: 25,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rank <= 3 ? const Color(0xFFFFD54F) : Colors.white70,
                fontSize: rank <= 3 ? 20 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 15),
          
          // Avatar with Frame
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: item['user_photo_url'] != null && item['user_photo_url'].toString().isNotEmpty
                      ? NetworkImage(item['user_photo_url'])
                      : const AssetImage('assets/mipmap-xxhdpi/avatar_default.png') as ImageProvider,
                ),
                if (frameAsset != null)
                  Image.asset(frameAsset, width: 70, height: 70, fit: BoxFit.cover),
              ],
            ),
          ),
          const SizedBox(width: 15),
          
          // Name and Value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item['user_name'],
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Image.asset('assets/mipmap-xxhdpi/icon_coin.webp', width: 14, height: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${item['total_value']}',
                      style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildMainTabItem('السحر', 1),
        const SizedBox(width: 40),
        _buildMainTabItem('الثروة', 0),
      ],
    );
  }

  Widget _buildMainTabItem(String title, int index) {
    bool isActive = _mainTabIndex == index;
    return GestureDetector(
      onTap: () => _onMainTabChanged(index),
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
          _buildSubTabItem('شهريا', 2),
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
        onTap: () => _onSubTabChanged(index),
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
