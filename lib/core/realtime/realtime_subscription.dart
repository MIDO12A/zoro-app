import '../supabase_compat.dart';

class RealtimeSubscription {
  final RealtimeChannel channel;
  RealtimeSubscription(this.channel);

  void dispose() => Supabase.instance.client.removeChannel(channel);
}
