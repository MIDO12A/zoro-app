class ServerTimeService {
  static final ServerTimeService instance = ServerTimeService._();
  ServerTimeService._();

  DateTime _cached = DateTime.now();

  DateTime now() => _cached;
  int get dayOfMonth => _cached.day;

  void sync(DateTime serverTime) {
    _cached = serverTime;
  }
}
