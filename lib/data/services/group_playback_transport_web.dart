import 'dart:async';

typedef GroupMessageHandler = FutureOr<void> Function(Map<String, dynamic>);
typedef GroupCountHandler = void Function(int);

class GroupPlaybackTransport {
  bool get supported => false;

  Future<String> startHost({
    required int port,
    required GroupMessageHandler onMessage,
    required GroupCountHandler onCount,
  }) =>
      throw UnsupportedError('Group playback requires the installed app.');

  Future<void> join({
    required String host,
    required int port,
    required GroupMessageHandler onMessage,
    required GroupCountHandler onCount,
  }) =>
      throw UnsupportedError('Group playback requires the installed app.');

  Future<void> send(Map<String, dynamic> message) async {}
  Future<void> close() async {}
}
