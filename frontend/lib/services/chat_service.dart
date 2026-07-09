import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import 'auth_service.dart';
import '../config.dart';

const String API_BASE_URL = AppConfig.baseUrl;

class ChatService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Exception _errorFrom(http.Response res) {
    try {
      final m = json.decode(res.body);
      final msg = m['detail'] ?? m['message'] ?? res.body;
      return Exception(msg.toString());
    } catch (_) {
      return Exception(res.body);
    }
  }

  static Future<ChatMessage> sendMessage(
    String classId,
    String receiverId,
    String content,
  ) async {
    final url = Uri.parse('$API_BASE_URL/chat/class/$classId/messages');
    final res = await http.post(
      url,
      headers: await _headers(),
      body: json.encode({'receiver_id': receiverId, 'content': content}),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return ChatMessage.fromJson(json.decode(res.body));
    }
    throw _errorFrom(res);
  }

  static Future<List<ChatMessage>> getConversation(
    String classId,
    String otherUserId,
  ) async {
    final url = Uri.parse('$API_BASE_URL/chat/class/$classId/conversation/$otherUserId');
    final res = await http.get(url, headers: await _headers());
    if (res.statusCode == 200) {
      final list = (json.decode(res.body) as List).cast<dynamic>();
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _errorFrom(res);
  }
}
