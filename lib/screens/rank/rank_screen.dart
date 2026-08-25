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

class _RankScreenState extends State<RankScreen>
    with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _wealthSubTabController;
  late TabController _charmSubTabController;
  late TabController _roomSubTabController;
  final SupabaseService _api = SupabaseService();
  DynamicConfigService get _cfg => DynamicConfigService();
  final Map<String, List<Map<String, dynamic>>> _cachedRankings = {};
  bool _loading = true;
  String _currentType = 'wealth';

  IconData _rankIcon(String iconName) {
    const map = {
      'Icons.emoji_events': Icons.emoji_events,
      'Icons.stars': Icons.stars,
      'Icons.military_tech': Icons.military_tech,
      'Icons.workspace_premium': Icons.workspace_premium,
      'Icons.verified': Icons.verified,
      'Icons.favorite': Icons.favorite,
      'Icons.whatshot': Icons.whatshot,
      'Icons.auto_awesome': Icons.auto_awesome,
      'Icons.diamond': Icons.diamond,
    };
    return map[iconName] ?? Icons.emoji_events;
  }

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 3, vsync: this);
    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
        setState(() {
          _currentType = ['wealth', 'charm', 'room'][_mainTabController.index];
        });
      }
    });
    _wealthSubTabController = TabController(length: 4, vsync: this);
    _charmSubTabController = TabController(length: 4, vsync: this);
    _roomSubTabController = TabController(length: 4, vsync: this);
    _loadRankings();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _wealthSubTabController.dispose();
    _charmSubTabController.dispose();
    _roomSubTabController.dispose();
    super.dispose();
  }

  Future<void> _loadRankings() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getUserRanking(orderByField: 'total_gifts_sent'),
        _api.getUserRanking(orderByField: 'total_gifts_received'),
        _api.getRoomRanking(),
      ]);
      if (mounted) {
        setState(() {
          _cachedRankings['wealth'] = results[0];
          _cachedRankings['charm'] = results[1];
          _cachedRankings['room'] = results[2];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _getRankingData(
      _RankPeriod period, String type) {
    final data = _cachedRankings[type] ?? [];
    if (type == 'room') return data;
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
        'hasFrame': false,
        'frameAsset': null,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<DynamicConfigService>();
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ListenableBuilder(
              listenable: _cfg,
              builder: (context, _) {
                final bg = _cfg.rankBgFor(_currentType);
                return bg.isNotEmpty
                    ? R.loadImage(bg, fit: BoxFit.cover)
                    : R.image('assets/mipmap-xxhdpi/rank_wealth_bg.webp', fit: BoxFit.cover);
              },
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
                      _buildRankPage('room', _roomSubTabController),
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: R.image(R.backIc, width: 24, height: 24),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TabBar(
                controller: _mainTabController,
                indicator: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                      'assets/mipmap-xxhdpi/rank_tab_item_bg.webp',
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(text: 'Wealth'),
                  Tab(text: 'Charm'),
                  Tab(text: 'Room'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankPage(String type, TabController subTabController) {
    return Column(
      children: [
        Container(
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(18),
          ),
          child: TabBar(
            controller: subTabController,
            indicator: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(18),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Daily'),
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
              Tab(text: 'All'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: subTabController,
            children: [
              _buildRankList(type, _RankPeriod.daily),
              _buildRankList(type, _RankPeriod.weekly),
              _buildRankList(type, _RankPeriod.monthly),
              _buildRankList(type, _RankPeriod.all),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankList(String type, _RankPeriod period) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: _cfg.rankTextColorFor(_currentType)),
      );
    }

    final data = _getRankingData(period, type);
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_rankIcon(_cfg.rankTrophyIcon), size: 64, color: _cfg.rankTextColorFor(_currentType).withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              _cfg.rankEmptyText,
              style: TextStyle(
                fontSize: 15,
                color: _cfg.rankSubTextColorFor(_currentType),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.length >= 3)
          Container(
            height: 240,
            margin: const EdgeInsets.only(top: 4),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: FittedBox(child: _buildTopRankItem(data[0], 1, type)),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FittedBox(child: _buildTopRankItem(data[1], 2, type)),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: FittedBox(child: _buildTopRankItem(data[2], 3, type)),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.length > 3 ? data.length - 3 : 0,
            itemBuilder: (context, index) {
              return _buildNormalItem(data[index + 3], index + 4, type);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopRankItem(Map<String, dynamic> item, int rank, String type) {
    final isGold = rank == 1;
    final isSilver = rank == 2;
    final size = isGold ? 100.0 : 80.0;
    final borderColor = isGold
        ? _cfg.rankGoldColorFor(type)
        : isSilver
            ? _cfg.rankSilverColorFor(type)
            : _cfg.rankBronzeColorFor(type);

    final frameUrl = _getRankingFrame(type, rank);

    return Container(
      width: size + 40,
      height: size + 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size + 20,
            height: size + 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size + 12,
                  height: size + 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: borderColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black26,
                  ),
                  child: ClipOval(
                    child: item['photoUrl'] != null &&
                            item['photoUrl'].toString().isNotEmpty
                        ? Image(
                            image: R.cachedImage(item['photoUrl'].toString()),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _rankAvatarFallback(item),
                          )
                        : _rankAvatarFallback(item),
                  ),
                ),
                if (frameUrl != null)
                  Positioned.fill(
                    child: R.loadImage(frameUrl, fit: BoxFit.contain),
                  ),
                if (item['hasFrame'] == true)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: borderColor,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$rank',
                style: TextStyle(
                  fontSize: isGold ? 13 : 11,
                  fontWeight: FontWeight.bold,
                  color: borderColor,
                ),
              ),
              if (isGold) ...[
                const SizedBox(width: 4),
                Icon(_rankIcon(_cfg.rankTrophyIcon), size: 16, color: borderColor),
              ],
            ],
          ),
          Text(
            item['name'] as String,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _cfg.rankTextColorFor(type),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _formatPoints((item['points'] as int?) ?? 0),
            style:             TextStyle(fontSize: 11, color: _cfg.rankPointsColorFor(type)),
          ),
        ],
      ),
    );
  }

  Widget _rankAvatarFallback(Map<String, dynamic> item) {
    return Center(
      child: Text(
        (item['name'] as String).isNotEmpty
            ? (item['name'] as String)[0].toUpperCase()
            : '?',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildNormalItem(Map<String, dynamic> item, int rank, String type) {
    String label = type == 'room'
        ? '${item['hostName'] as String}'
        : '';
    String suffix = type == 'room' ? '' : 'pts';

    return Container(
      height: 68,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: rank <= 3
                    ? const Color(0xFFFFD700)
                    : const Color(0xFF16151A),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                child: item['photoUrl'] != null &&
                        item['photoUrl'].toString().isNotEmpty
                    ? ClipOval(
                        child: Image(
                          image: R.cachedImage(item['photoUrl'].toString()),
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(
                            (item['name'] as String)[0].toUpperCase(),
                          ),
                        ),
                      )
                    : Text(
                        (item['name'] as String).isNotEmpty
                            ? (item['name'] as String)[0].toUpperCase()
                            : '?',
                      ),
              ),
              if (item['hasFrame'] == true)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16151A),
                  ),
                ),
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9BA1B6),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: Text(
              '${_formatPoints((item['points'] as int?) ?? 0)} $suffix',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF894916),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String? _getRankingFrame(String category, int rank) => null;

  String _formatPoints(int points) {
    if (points >= 1000000) {
      return '${(points / 1000000).toStringAsFixed(1)}M';
    } else if (points >= 1000) {
      return '${(points / 1000).toStringAsFixed(1)}K';
    }
    return points.toString();
  }
}
