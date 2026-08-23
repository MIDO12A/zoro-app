import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/room_audio_service.dart';

/// Global service to track minimized room state
class MinimizedRoomService extends ChangeNotifier {
  static final MinimizedRoomService _instance = MinimizedRoomService._();
  factory MinimizedRoomService() => _instance;
  MinimizedRoomService._();

  bool _isActive = false;
  String? _roomId;
  String? _roomName;
  String? _hostName;
  String? _roomPassword;
  String? _hotValue;
  String? _gameDesc;
  String? _roomPhoto;
  RoomAudioService? _audioService;

  bool get isActive => _isActive;
  String? get roomId => _roomId;
  String? get roomName => _roomName;
  String? get hostName => _hostName;
  String? get roomPassword => _roomPassword;
  String? get hotValue => _hotValue;
  String? get gameDesc => _gameDesc;
  String? get roomPhoto => _roomPhoto;

  void activate({
    required String roomId,
    required String roomName,
    String? hostName,
    String? roomPassword,
    String? hotValue,
    String? gameDesc,
    String? roomPhoto,
    RoomAudioService? audioService,
  }) {
    _isActive = true;
    _roomId = roomId;
    _roomName = roomName;
    _hostName = hostName;
    _roomPassword = roomPassword;
    _hotValue = hotValue;
    _gameDesc = gameDesc;
    _roomPhoto = roomPhoto;
    _audioService = audioService;
    notifyListeners();
  }

  void deactivate() {
    _isActive = false;
    _roomId = null;
    _roomName = null;
    _hostName = null;
    _roomPassword = null;
    _hotValue = null;
    _gameDesc = null;
    _roomPhoto = null;
    _audioService?.dispose();
    _audioService = null;
    notifyListeners();
  }

  /// Clean up room from Firebase
  void exitRoom(String userId) {
    if (_roomId != null) {
      SupabaseService().leaveRoom(_roomId!, userId);
    }
    deactivate();
  }
}
