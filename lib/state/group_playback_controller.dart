import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/group_playback_transport.dart';
import 'playback_controller.dart';
import 'providers.dart';

enum GroupPlaybackMode { disconnected, hosting, joined }

class GroupPlaybackState {
  final GroupPlaybackMode mode;
  final String? address;
  final int deviceCount;
  final String? error;

  const GroupPlaybackState({
    this.mode = GroupPlaybackMode.disconnected,
    this.address,
    this.deviceCount = 1,
    this.error,
  });

  GroupPlaybackState copyWith({
    GroupPlaybackMode? mode,
    String? address,
    int? deviceCount,
    String? error,
    bool clearError = false,
  }) =>
      GroupPlaybackState(
        mode: mode ?? this.mode,
        address: address ?? this.address,
        deviceCount: deviceCount ?? this.deviceCount,
        error: clearError ? null : error ?? this.error,
      );
}

class GroupPlaybackController extends StateNotifier<GroupPlaybackState> {
  static const port = 45872;
  final Ref _ref;
  final GroupPlaybackTransport _transport = GroupPlaybackTransport();
  Timer? _broadcastTimer;
  bool _applyingRemote = false;

  GroupPlaybackController(this._ref) : super(const GroupPlaybackState());

  bool get supported => _transport.supported;

  Future<void> host() async {
    try {
      final address = await _transport.startHost(
        port: port,
        onMessage: (_) {},
        onCount: (count) =>
            state = state.copyWith(deviceCount: count, clearError: true),
      );
      state = GroupPlaybackState(
        mode: GroupPlaybackMode.hosting,
        address: '$address:$port',
      );
      _broadcastTimer?.cancel();
      _broadcastTimer = Timer.periodic(
        const Duration(milliseconds: 750),
        (_) => _broadcast(),
      );
      await _broadcast();
    } catch (error) {
      state = state.copyWith(error: 'Could not host group: $error');
    }
  }

  Future<void> join(String rawAddress) async {
    try {
      final parts = rawAddress.trim().split(':');
      final host = parts.first;
      final parsedPort =
          parts.length > 1 ? int.tryParse(parts.last) ?? port : port;
      await _transport.join(
        host: host,
        port: parsedPort,
        onMessage: _applyRemote,
        onCount: (count) =>
            state = state.copyWith(deviceCount: count, clearError: true),
      );
      state = GroupPlaybackState(
        mode: GroupPlaybackMode.joined,
        address: '$host:$parsedPort',
        deviceCount: 2,
      );
    } catch (error) {
      state = state.copyWith(error: 'Could not join group: $error');
    }
  }

  Future<void> _broadcast() async {
    if (_applyingRemote || state.mode != GroupPlaybackMode.hosting) return;
    final playback = _ref.read(playbackControllerProvider);
    final track = playback.current;
    if (track == null) return;
    final player = _ref.read(playbackControllerProvider.notifier).player;
    await _transport.send({
      'v': 1,
      'trackId': track.id,
      'positionMs': player.position.inMilliseconds,
      'playing': playback.isPlaying,
      'sentAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _applyRemote(Map<String, dynamic> message) async {
    if (state.mode != GroupPlaybackMode.joined) return;
    final trackId = message['trackId'] as String?;
    if (trackId == null) return;
    _applyingRemote = true;
    try {
      final playback = _ref.read(playbackControllerProvider);
      final controller = _ref.read(playbackControllerProvider.notifier);
      if (playback.current?.id != trackId) {
        final track = await _ref.read(trackDaoProvider).getById(trackId);
        if (track == null) {
          state = state.copyWith(
            error: 'This song is not available on this device.',
          );
          return;
        }
        await controller.playSingle(track);
      }

      final playing = message['playing'] == true;
      final sentAt = (message['sentAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch;
      var targetMs = (message['positionMs'] as num?)?.toInt() ?? 0;
      if (playing) {
        targetMs += DateTime.now().millisecondsSinceEpoch - sentAt;
      }
      targetMs = targetMs.clamp(0, 1 << 31).toInt();
      final drift =
          (controller.player.position.inMilliseconds - targetMs).abs();
      if (drift > 280) {
        await controller.seek(Duration(milliseconds: targetMs));
      }
      if (playing && !controller.player.playing) await controller.player.play();
      if (!playing && controller.player.playing) await controller.player.pause();
    } finally {
      _applyingRemote = false;
    }
  }

  Future<void> leave() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    await _transport.close();
    state = const GroupPlaybackState();
  }

  @override
  void dispose() {
    _broadcastTimer?.cancel();
    _transport.close();
    super.dispose();
  }
}

final groupPlaybackControllerProvider =
    StateNotifierProvider<GroupPlaybackController, GroupPlaybackState>(
  (ref) => GroupPlaybackController(ref),
);
