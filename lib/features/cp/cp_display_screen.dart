import 'package:flutter/material.dart';
import '../../core/cache/encrypted_image_provider.dart';
import '../../services/dynamic_config_service.dart';
import 'cp_service.dart';
import 'cp_invitation_list_screen.dart';

class CcDisplayScreen extends StatefulWidget {
  const CcDisplayScreen({super.key});

  @override
  State<CcDisplayScreen> createState() => _CcDisplayScreenState();
}

class _CcDisplayScreenState extends State<CcDisplayScreen> {
  List<Map<String, dynamic>> _couples = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCouples();
  }

  Future<void> _loadCouples() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final ranking = await CpService.getRanking(period: 'total', limit: 50);
      if (mounted) {
        setState(() {
          _couples = ranking;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('العلاقات', style: TextStyle(color: cfg.cpHeaderText, fontSize: 16)),
            const SizedBox(width: 4),
            Text('(${_couples.length})', style: TextStyle(color: cfg.cpSubText, fontSize: 14)),
          ],
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CcInvitationListScreen()),
            ),
            child: Container(
              margin: const EdgeInsetsDirectional.only(end: 12),
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mail_outline, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cfg.cpGold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white54)))
              : RefreshIndicator(
                  onRefresh: _loadCouples,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                    itemCount: _couples.length,
                    itemBuilder: (_, i) => _buildCoupleItem(cfg, _couples[i], i),
                  ),
                ),
    );
  }

  Widget _buildCoupleItem(DynamicConfigService cfg, Map<String, dynamic> item, int index) {
    final u1 = item['user1'] as Map<String, dynamic>? ?? {};
    final u2 = item['user2'] as Map<String, dynamic>? ?? {};
    final score = (item['score'] as num?)?.toInt() ?? 0;
    final rank = index + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cfg.cpCardBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cfg.cpCardBorder, width: 1),
      ),
      child: Row(
        children: [
          Text('$rank', style: TextStyle(
            color: rank <= 3 ? cfg.cpGold : cfg.cpSubText,
            fontWeight: FontWeight.bold, fontSize: 16,
          )),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundImage: EncryptedImageProvider(u1['avatar'] as String? ?? ''),
            onBackgroundImageError: (_, __) {},
          ),
          const SizedBox(width: 4),
          Icon(Icons.favorite, color: cfg.cpGold, size: 14),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 20,
            backgroundImage: EncryptedImageProvider(u2['avatar'] as String? ?? ''),
            onBackgroundImageError: (_, __) {},
          ),
          const Spacer(),
          Text('$score', style: TextStyle(color: cfg.cpGold, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 4),
          Text('نقطة', style: TextStyle(color: cfg.cpSubText, fontSize: 11)),
        ],
      ),
    );
  }
}
