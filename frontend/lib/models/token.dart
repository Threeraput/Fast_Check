// File: frontend/lib/models/token.dart
import 'package:frontend/models/users.dart';

class Token {
  final String accessToken;
  final String tokenType;
  final User user; // เพิ่มข้อมูลผู้ใช้เข้ามาใน Token response

  Token({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
      user: User.fromJson(json['user']), // แปลง user data
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'user': user.toJson(),
    };
  }
}
