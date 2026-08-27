import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/r.dart';
import '../../services/supabase_service.dart';
import '../../services/dynamic_config_service.dart';

enum _RankPeriod { daily, weekly, monthly, all }

class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _wealthSubTabController;
  late TabController _charmSubTabController;
  final SupabaseService _api = SupabaseService();
  final Map<String, List<Map<String, dynamic>>> _cachedRankings = {};
  bool _loading = true;
  String _currentType = 'wealth';

  Timer? _countdownTimer;
  String _countdownStr = '00h 00m 00s';

  String _getCountdownString() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '${h}h ${m}m ${s}s';
  }

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
        setState(() {
          _currentType = ['wealth', 'charm'][_mainTabController.index];
        });
      }
    });
    _wealthSubTabController = TabController(length: 3, vsync: this);
    _charmSubTabController = TabController(length: 3, vsync: this);
    _loadRankings();

    _countdownStr = _getCountdownString();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _countdownStr = _getCountdownString();
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _mainTabController.dispose();
    _wealthSubTabController.dispose();
    _charmSubTabController.dispose();
    super.dispose();
  }

  Future<void> _loadRankings() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getUserRanking(orderByField: 'total_gifts_sent'),
        _api.getUserRanking(orderByField: 'total_gifts_received'),
      ]);
      if (mounted) {
        setState(() {
          _cachedRankings['wealth'] = results[0];
          _cachedRankings['charm'] = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _getRankingData(_RankPeriod period, String type) {
    final data = _cachedRankings[type] ?? [];
    return data.map((e) {
      final points = type == 'wealth'
          ? (e['total_gifts_sent'] ?? 0)
          : (e['total_gifts_received'] ?? 0);
      return {
        'uid': e['uid'] ?? '',
        'name': e['name'] ?? 'Unknown',
        'photoUrl': e['photo_url'] ?? '',
        'points': points,
        'level': e['level'] ?? 1,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/mipmap-xxhdpi/room_rank_bg.png', // Using the grand room background for now
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _mainTabController,
                    children: [
                      _buildRankPage('wealth', _wealthSubTabController),
                      _buildRankPage('charm', _charmSubTabController),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: TabBar(
                  controller: _mainTabController,
                  indicatorColor: const Color(0xFFFFD54F),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFFFFD54F),
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'الثروة'),
                    Tab(text: 'السحر'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 36), // Balance space for back button
          ],
        ),
      ),
    );
  }

  Widget _buildRankPage(String type, TabController subTabController) {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Sub Tabs
        Container(
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.3)),
          ),
          child: TabBar(
            controller: subTabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD54F), Color(0xFFF57F17)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            labelColor: Colors.black,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'يوميا'),
              Tab(text: 'أسبوعيًا'),
              Tab(text: 'شهريا'),
            ],
          ),
        ),
        const SizedBox(height: 15),
        // Countdown
        Text(
          'العد التنازلي: (GMT+3) $_countdownStr',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        
        // List
        Expanded(
          child: TabBarView(
            controller: subTabController,
            children: [
              _buildRankList(type, _RankPeriod.daily),
              _buildRankList(type, _RankPeriod.weekly),
              _buildRankList(type, _RankPeriod.all),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankList(String type, _RankPeriod period) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD54F)),
      );
    }

    final data = _getRankingData(period, type);
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد بيانات ترتيب حالياً',
          style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
        ),
      );
    }

    return Column(
      children: [
        // Top 3 Podium
        if (data.isNotEmpty)
          Container(
            height: 280,
            padding: const EdgeInsets.only(top: 10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (data.length >= 2)
                  Positioned(
                    right: 15,
                    bottom: 0,
                    child: _buildTopRankItem(data[1], 2),
                  ),
                if (data.length >= 3)
                  Positioned(
                    left: 15,
                    bottom: 0,
                    child: _buildTopRankItem(data[2], 3),
                  ),
                if (data.length >= 1)
                  Positioned(
                    top: 0,
                    child: _buildTopRankItem(data[0], 1),
                  ),
              ],
            ),
          ),
        
        const SizedBox(height: 15),
        
        // Ranks 4+ List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.length > 3 ? data.length - 3 : 0,
            itemBuilder: (context, index) {
              return _buildNormalItem(data[index + 3], index + 4);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopRankItem(Map<String, dynamic> item, int rank) {
    final isGold = rank == 1;
    final isSilver = rank == 2;
    
    String bannerAsset;
    if (rank == 1) bannerAsset = 'assets/mipmap-xxhdpi/global_rank_asset_7.png'; // Red banner
    else if (rank == 2) bannerAsset = 'assets/mipmap-xxhdpi/global_rank_asset_8.png'; // Purple banner
    else bannerAsset = 'assets/mipmap-xxhdpi/global_rank_asset_1.png'; // Blue banner

    String frameAsset;
    if (rank == 1) frameAsset = 'assets/mipmap-xxhdpi/rank_1_frame.png';
    else if (rank == 2) frameAsset = 'assets/mipmap-xxhdpi/rank_2_frame.png';
    else frameAsset = 'assets/mipmap-xxhdpi/global_rank_asset_6.png'; // New Top 3 frame

    final double width = isGold ? 130 : 100;
    final double avatarSize = isGold ? 60 : 50;

    return SizedBox(
      width: width,
      height: isGold ? 260 : 210,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Banner
          Positioned(
            top: avatarSize / 2 + 15,
            child: SizedBox(
              width: width - 10,
              height: isGold ? 190 : 150,
              child: Image.asset(
                bannerAsset,
                fit: BoxFit.fill,
              ),
            ),
          ),
          
          // Name and Points on Banner
          Positioned(
            bottom: isGold ? 65 : 45,
            child: Column(
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatPoints(item['points'])}',
                  style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12),
                ),
              ],
            ),
          ),

          // Avatar and Frame
          Positioned(
            top: 0,
            child: SizedBox(
              width: width,
              height: width,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: avatarSize / 2,
                    backgroundImage: item['photoUrl'] != null && item['photoUrl'].toString().isNotEmpty
                        ? NetworkImage(item['photoUrl'])
                        : const AssetImage('assets/mipmap-xxhdpi/avatar_default.png') as ImageProvider,
                  ),
                  Image.asset(frameAsset, width: width, height: width, fit: BoxFit.contain),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalItem(Map<String, dynamic> item, int rank) {
    return Container(
      height: 75,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/mipmap-xxhdpi/global_rank_asset_3.png'), // Dark card bg
          fit: BoxFit.fill,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          SizedBox(
            width: 30,
            child: Text(
              rank < 10 ? '0$rank' : '$rank',
              style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 15),
          CircleAvatar(
            radius: 22,
            backgroundImage: item['photoUrl'] != null && item['photoUrl'].toString().isNotEmpty
                ? NetworkImage(item['photoUrl'])
                : const AssetImage('assets/mipmap-xxhdpi/avatar_default.png') as ImageProvider,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              Image.asset('assets/mipmap-xxhdpi/icon_coin.webp', width: 14, height: 14),
              const SizedBox(width: 4),
              Text(
                '${_formatPoints(item['points'])} ↑',
                style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(width: 25),
        ],
      ),
    );
  }

  String _formatPoints(int points) {
    if (points >= 1000000) {
      return '${(points / 1000000).toStringAsFixed(1)}M';
    } else if (points >= 1000) {
      return '${(points / 1000).toStringAsFixed(1)}K';
    }
    return points.toString();
  }
}
