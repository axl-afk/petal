import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef GroupMessageHandler = FutureOr<void> Function(Map<String, dynamic>);
typedef GroupCountHandler = void Function(int);

class GroupPlaybackTransport {
  HttpServer? _server;
  WebSocket? _socket;
  final _clients = <WebSocket>{};
  GroupMessageHandler? _onMessage;
  GroupCountHandler? _onCount;

  bool get supported => true;

  Future<String> startHost({
    required int port,
    required GroupMessageHandler onMessage,
    required GroupCountHandler onCount,
  }) async {
    await close();
    _onMessage = onMessage;
    _onCount = onCount;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request) ||
          request.uri.path != '/petal-group') {
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
        return;
      }
      if (_clients.length >= 5) {
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..write('This Petal group already has six devices.')
          ..close();
        return;
      }
      final client = await WebSocketTransformer.upgrade(request);
      _clients.add(client);
      _onCount?.call(_clients.length + 1);
      client.listen(
        _receive,
        onDone: () => _removeClient(client),
        onError: (_) => _removeClient(client),
        cancelOnError: true,
      );
    });
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final address = interfaces
        .expand((interface) => interface.addresses)
        .map((address) => address.address)
        .firstWhere(
          (address) => !address.startsWith('169.254.'),
          orElse: () => '127.0.0.1',
        );
    _onCount?.call(1);
    return address;
  }

  Future<void> join({
    required String host,
    required int port,
    required GroupMessageHandler onMessage,
    required GroupCountHandler onCount,
  }) async {
    await close();
    _onMessage = onMessage;
    _onCount = onCount;
    _socket = await WebSocket.connect('ws://$host:$port/petal-group');
    _onCount?.call(2);
    _socket!.listen(
      _receive,
      onDone: () => _onCount?.call(1),
      onError: (_) => _onCount?.call(1),
      cancelOnError: true,
    );
  }

  void _receive(dynamic raw) {
    if (raw is! String) return;
    try {
      _onMessage?.call(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
  }

  void _removeClient(WebSocket client) {
    _clients.remove(client);
    _onCount?.call(_clients.length + 1);
  }

  Future<void> send(Map<String, dynamic> message) async {
    final encoded = jsonEncode(message);
    if (_socket != null) {
      _socket!.add(encoded);
      return;
    }
    for (final client in _clients.toList()) {
      try {
        client.add(encoded);
      } catch (_) {
        _removeClient(client);
      }
    }
  }

  Future<void> close() async {
    await _socket?.close();
    _socket = null;
    for (final client in _clients.toList()) {
      await client.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
