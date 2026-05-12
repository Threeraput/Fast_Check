import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'auth_service.dart';
import '../config.dart';

class LiveAttendanceWsService {
  WebSocketChannel? _channel;

  Future<Stream<Map<String, dynamic>>> connect({
    required String sessionId,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated - no token found');
    }

    print('🔗 WebSocket connecting with token: ${token.substring(0, 20)}...');
    print('🔗 Base URL: ${AppConfig.baseUrl}');

    final apiUri = Uri.parse(AppConfig.baseUrl);
    final wsScheme = apiUri.scheme == 'https' ? 'wss' : 'ws';

    // Build WebSocket URL manually with correct scheme
    final host = apiUri.host;
    final port = apiUri.hasPort ? ':${apiUri.port}' : '';
    final wsUriString =
        '$wsScheme://$host$port/api/v1/attendance/sessions/$sessionId/live?token=$token';

    print('🔗 WebSocket URI: $wsUriString');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUriString));
      print('✅ WebSocket channel created');
    } catch (e) {
      print('❌ WebSocket connection error: $e');
      rethrow;
    }

    return _channel!.stream.map((dynamic raw) {
      if (raw is String) {
        print('📨 WebSocket received string: ${raw.substring(0, 100)}...');
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          print('✅ Decoded event: ${decoded['event']}');
          return decoded;
        }
      }
      if (raw is Map<String, dynamic>) {
        print('✅ Received map: ${raw['event']}');
        return raw;
      }
      print('⚠️ Unknown message type: ${raw.runtimeType}');
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
