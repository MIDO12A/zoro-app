import 'package:flutter/material.dart';
import '../../services/dynamic_config_service.dart';
import 'cp_service.dart';

class CcRecordScreen extends StatefulWidget {
  const CcRecordScreen({super.key});

  @override
  State<CcRecordScreen> createState() => _CcRecordScreenState();
}

class _CcRecordScreenState extends State<CcRecordScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allRecords = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final records = await CpService.getCpHistory(limit: 100);
      if (mounted) {
        setState(() {
          _allRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = DynamicConfigService();

    return Scaffold(
      backgroundColor: cfg.cpHeaderBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('سجل العلاقات',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicator: const BoxDecoration(),
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: cfg.cpGold,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 16),
            splashFactory: NoSplash.splashFactory,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'الكل'),
              Tab(text: 'المرسلة'),
              Tab(text: 'المستلمة'),
            ],
          ),
      ),
      body: _buildBody(cfg),
    );
  }

  Widget _buildBody(DynamicConfigService cfg) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: cfg.cpGold),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white54),
            const SizedBox(height: 16),
            const Text('حدث خطأ في تحميل السجل',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadHistory,
              style: ElevatedButton.styleFrom(
                  backgroundColor: cfg.cpGold),
              child: const Text('إعادة المحاولة',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildRecordList(cfg, _allRecords),
        _buildRecordList(cfg, _allRecords.where((r) => r['direction'] == 'sent').toList()),
        _buildRecordList(cfg, _allRecords.where((r) => r['direction'] == 'received').toList()),
      ],
    );
  }

  Widget _buildRecordList(DynamicConfigService cfg, List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            const Text('لا توجد سجلات',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: records.length,
      itemBuilder: (context, index) => _buildRecordItem(cfg, records[index]),
    );
  }

  Widget _buildRecordItem(DynamicConfigService cfg, Map<String, dynamic> item) {
    final userName = item['user_name'] as String? ?? '';
    final giftName = item['gift_name'] as String? ?? '';
    final giftValue = (item['gift_value'] as num?)?.toInt() ?? 0;
    final timestamp = item['timestamp'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cfg.cpCardBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cfg.cpCardBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cfg.cpGold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_giftcard,
              color: cfg.cpGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (giftName.isNotEmpty)
                  Text('$giftName 🎁',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                Text(userName,
                    style: TextStyle(
                        color: cfg.cpSubText, fontSize: 12)),
                if (giftValue > 0)
                  Text('$giftValue نقطة',
                      style: TextStyle(
                          color: cfg.cpGold, fontSize: 11)),
                if (timestamp.isNotEmpty)
                  Text(_formatTime(timestamp),
                      style: TextStyle(
                          color: cfg.cpSubText, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final time = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(time);
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
      return 'منذ ${diff.inDays} ي';
    } catch (_) {
      return '';
    }
  }
}
