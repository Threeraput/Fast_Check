// lib/models/feed_item.dart
import 'package:flutter/foundation.dart';

enum FeedType { checkin, assignment, announcement }

@immutable
class FeedItem {
  final String id;
  final String classId;
  final FeedType type;
  final String title;
  final String? subtitle; // เช่น เนื้อหาประกาศสั้น ๆ
  final DateTime postedAt;
  final DateTime? expiresAt; // สำหรับเช็คชื่อ / งาน
  final Map<String, dynamic> extra; // เก็บค่าเฉพาะชนิด เช่น radius, anchor ฯลฯ

  const FeedItem({
    required this.id,
    required this.classId,
    required this.type,
    required this.title,
    required this.postedAt,
    this.subtitle,
    this.expiresAt,
    this.extra = const {},
  });
}
