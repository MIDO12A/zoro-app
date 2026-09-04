import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import '../config/app_config.dart';

class RoomAudioService {
  static final RoomAudioService _instance = RoomAudioService._();
  factory RoomAudioService() => _instance;
  RoomAudioService._();

  bool _initialized = false;
  bool _micEnabled = true;
  bool _isPublishing = false;
  String? _currentRoomId;
  String? _currentUid;

  // Serialize engine lifecycle: never allow two createEngineWithProfile /
  // destroyEngine calls to overlap (overlapping calls crash natively inside
  // libZegoExpressEngine.so -> zego_express_engine_init with SIGSEGV).
  Future<bool>? _initFuture;
  Future<void>? _disposeFuture;

  bool get isInitialized => _initialized;
  bool get isMicEnabled => _micEnabled;

  void _onRoomStreamUpdate(String roomID, ZegoUpdateType updateType,
      List<ZegoStream> streamList, Map<String, dynamic> extendedData) {
    final engine = ZegoExpressEngine.instance;
    if (engine == null) return;
    for (final stream in streamList) {
      if (updateType == ZegoUpdateType.Add) {
        engine.startPlayingStream(stream.streamID);
        debugPrint('[ZegoAudio] Started playing stream: ${stream.streamID}');
      } else {
        engine.stopPlayingStream(stream.streamID);
        debugPrint('[ZegoAudio] Stopped playing stream: ${stream.streamID}');
      }
    }
  }

  Future<bool> initialize() {
    if (_initialized) return Future<bool>.value(true);
    // Reuse the in-flight init so concurrent callers (double room push,
    // rapid enter/exit) share one createEngineWithProfile call.
    return _initFuture ??= _doInitialize().whenComplete(() => _initFuture = null);
  }

  Future<bool> _doInitialize() async {
    try {
      if (AppConfig.zegoAppSign.isEmpty) {
        debugPrint('[RoomAudioService] Zego appSign missing — build with --dart-define=ZEGO_APP_SIGN');
        return false;
      }
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('[RoomAudioService] Microphone permission denied');
        return false;
      }
      // If a destroy is still running from a previous room, wait for it.
      await _disposeFuture;
      await ZegoExpressEngine.createEngineWithProfile(ZegoEngineProfile(
        AppConfig.zegoAppId, ZegoScenario.Default, appSign: AppConfig.zegoAppSign,
      ));
      ZegoExpressEngine.onRoomStreamUpdate = _onRoomStreamUpdate;
      _initialized = true;
      debugPrint('[RoomAudioService] Zego engine initialized (appId=${AppConfig.zegoAppId})');
      return true;
    } catch (e) {
      debugPrint('[RoomAudioService] Init failed: $e');
      return false;
    }
  }

  Future<void> joinChannel(String channelName, String uid) async {
    if (!_initialized) {
      debugPrint('[RoomAudioService] Cannot join: not initialized');
      return;
    }
    try {
      await leaveChannel();
      _currentRoomId = channelName;
      _currentUid = uid;

      final engine = ZegoExpressEngine.instance;
      if (engine == null) {
        debugPrint('[RoomAudioService] Engine is null');
        return;
      }

      final user = ZegoUser(uid, uid);
      await engine.loginRoom(channelName, user, config: ZegoRoomConfig(0, true, ''));
      debugPrint('[RoomAudioService] Logged into room: $channelName');

      _micEnabled = true;
    } catch (e) {
      debugPrint('[RoomAudioService] joinChannel failed: $e');
    }
  }

  Future<void> startPublishing() async {
    if (_isPublishing || _currentRoomId == null || _currentUid == null) return;
    try {
      final engine = ZegoExpressEngine.instance;
      if (engine == null) return;
      final streamId = 'audio_${_currentUid}_$_currentRoomId';
      await engine.startPublishingStream(streamId);
      await engine.enableCamera(false);
      _isPublishing = true;
      debugPrint('[RoomAudioService] Started publishing stream: $streamId');
    } catch (e) {
      debugPrint('[RoomAudioService] startPublishing failed: $e');
    }
  }

  Future<void> leaveChannel() async {
    if (_currentRoomId == null) return;
    try {
      final engine = ZegoExpressEngine.instance;
      if (engine != null) {
        engine.stopPublishingStream();
        await engine.logoutRoom(_currentRoomId!);
      }
    } catch (e) {
      debugPrint('[RoomAudioService] leaveChannel failed: $e');
    }
    _currentRoomId = null;
    _isPublishing = false;
  }

  Future<bool> toggleMic(bool on) async {
    try {
      final engine = ZegoExpressEngine.instance;
      if (engine != null) {
        engine.mutePublishStreamAudio(!on);
      }
      _micEnabled = on;
      return true;
    } catch (e) {
      debugPrint('[RoomAudioService] toggleMic failed: $e');
      return false;
    }
  }

  void muteRemoteAudio(String uid, String channelName, bool muted) {
    try {
      final engine = ZegoExpressEngine.instance;
      if (engine != null) {
        final streamId = 'audio_${uid}_$channelName';
        engine.mutePlayStreamAudio(streamId, muted);
        debugPrint('[RoomAudioService] ${muted ? "Muted" : "Unmuted"} remote stream: $streamId');
      }
    } catch (e) {
      debugPrint('[RoomAudioService] muteRemoteAudio failed: $e');
    }
  }

  void resetPublishingState() {
    _isPublishing = false;
    _micEnabled = true;
    debugPrint('[RoomAudioService] Publishing state reset');
  }

  /// Pause mic publishing when the app goes to the background to save battery
  /// and avoid Zego SIGSEGV on some devices. Remote audio (listening) keeps
  /// running so the minimized room stays audible.
  void pauseForBackground() {
    if (!_isPublishing) return;
    try {
      final engine = ZegoExpressEngine.instance;
      engine?.stopPublishingStream();
      _isPublishing = false;
      debugPrint('[RoomAudioService] Publishing paused for background');
    } catch (e) {
      debugPrint('[RoomAudioService] pauseForBackground failed: $e');
    }
  }

  /// Restore mic publishing when the app returns to the foreground.
  Future<void> resumeFromBackground() async {
    if (_currentRoomId == null || _currentUid == null || _isPublishing) return;
    try {
      final engine = ZegoExpressEngine.instance;
      if (engine == null) return;
      final streamId = 'audio_${_currentUid}_$_currentRoomId';
      await engine.startPublishingStream(streamId);
      _isPublishing = true;
      debugPrint('[RoomAudioService] Publishing resumed from background');
    } catch (e) {
      debugPrint('[RoomAudioService] resumeFromBackground failed: $e');
    }
  }

  void stopRemoteStream(String uid, String channelName) {
    try {
      final engine = ZegoExpressEngine.instance;
      if (engine != null) {
        final streamId = 'audio_${uid}_$channelName';
        engine.stopPlayingStream(streamId);
        debugPrint('[RoomAudioService] Stopped remote stream: $streamId');
      }
    } catch (e) {
      debugPrint('[RoomAudioService] stopRemoteStream failed: $e');
    }
  }

  Future<void> dispose() {
    if (!_initialized && _disposeFuture == null) return Future<void>.value();
    // Serialize destroys too: a createEngine must never overlap a destroy.
    return _disposeFuture ??= _doDispose().whenComplete(() => _disposeFuture = null);
  }

  Future<void> _doDispose() async {
    // Wait for any in-flight init to finish before destroying.
    await _initFuture;
    await leaveChannel();
    try {
      ZegoExpressEngine.destroyEngine();
    } catch (e) {
      debugPrint('[RoomAudioService] destroy failed: $e');
    }
    _initialized = false;
    _micEnabled = true;
    debugPrint('[RoomAudioService] Disposed');
  }
}
