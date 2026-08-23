import 'package:flutter/material.dart';
import '../../../core/supabase_compat.dart';

import '../../../core/ui/in_app_toast.dart';

// ═══════════════════════════════════════════════════════════════════
//  AgencyNotificationHandler — يستمع لإشعارات الوكالة في الوقت الفعلي
//  يُستخدم كـ InheritedWidget أو يُلف حول الـ MaterialApp
//  الإشعارات المدعومة:
//    - agency_target_80pct     → "اقتربت من هدفك!"
//    - agency_target_achieved  → "أكملت الهدف! 🎉"
//    - agency_month_host       → "مضيف الشهر 🏆"
//    - agency_war_won          → "فزنا في الحرب! ⚔️"
//    - agency_month_host_announce → "إعلان مضيف الشهر"
// ═══════════════════════════════════════════════════════════════════
class AgencyNotificationHandler extends StatefulWidget {
  final Widget child;
  const AgencyNotificationHandler({super.key, required this.child});

  @override
  State<AgencyNotificationHandler> createState() => _AgencyNotificationHandlerState();
}

class _AgencyNotificationHandlerState extends State<AgencyNotificationHandler> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _channel = Supabase.instance.client
        .channel('agency_notifications_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final type   = record['type'] as String? ?? '';
            final title  = record['title'] as String? ?? '';
            final body   = record['body']  as String? ?? '';

            switch (type) {
              case 'agency_target_80pct':
              case 'agency_host_target_80pct':
                KayanInAppToast.agency('🎯 $title\n$body');
                break;
              case 'agency_target_achieved':
                KayanInAppToast.agency('🎉 $title\n$body');
                break;
              case 'agency_month_host':
                KayanInAppToast.agency('🏆 $title\n$body');
                break;
              case 'agency_war_won':
                KayanInAppToast.agency('⚔️ $title\n$body');
                break;
              case 'agency_month_host_announce':
                KayanInAppToast.agency('🎖️ $title\n$body');
                break;
              default:
                if (type.startsWith('agency_')) {
                  KayanInAppToast.agency('$title\n$body');
                }
            }
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

