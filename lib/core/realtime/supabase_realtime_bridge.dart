import '../supabase_compat.dart';
import 'realtime_subscription.dart';

abstract final class SupabaseRealtimeBridge {
  static RealtimeSubscription subscribePostgres({
    required String topic,
    required PostgresChangeEvent event,
    required String table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload payload) onPayload,
  }) {
    final sb = Supabase.instance.client;
    final channel = sb.channel(topic);

    channel.onPostgresChanges(
      schema: 'public',
      table: table,
      event: event,
      filter: filter,
      callback: onPayload,
    );

    channel.subscribe();

    return RealtimeSubscription(channel);
  }
}
