import '../models/users.dart';

class ChatMessage {
  final String messageId;
  final String classId;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final User? senderProfile;

  ChatMessage({
    required this.messageId,
    required this.classId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.senderProfile,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['message_id']?.toString() ?? '',
      classId: json['class_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      senderProfile: json['sender'] != null ? User.fromJson(json['sender']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'class_id': classId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
