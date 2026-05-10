import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'auth_service.dart';

class LiveAttendanceWsService {
  WebSocketChannel? _channel;

  Future<Stream<Map<String, dynamic>>> connect({
    required String sessionId,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final apiUri = Uri.parse(API_BASE_URL);
    final wsScheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    final basePath = apiUri.path.endsWith('/')
        ? apiUri.path.substring(0, apiUri.path.length - 1)
        : apiUri.path;

    final wsUri = Uri(
      scheme: wsScheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
      path: '$basePath/attendance/sessions/$sessionId/live',
      queryParameters: {'token': token},
    );

    _channel = WebSocketChannel.connect(wsUri);

    return _channel!.stream.map((dynamic raw) {
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      if (raw is Map<String, dynamic>) return raw;
      return <String, dynamic>{'event': 'unknown', 'raw': raw.toString()};
    });
  }

  void sendPing() {
    _channel?.sink.add('ping');
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }
}
