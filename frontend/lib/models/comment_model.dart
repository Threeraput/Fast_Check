// File: lib/models/comment_model.dart

class AssignmentComment {
  final String commentId;
  final String assignmentId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String commenterName; // ชื่อคนพิมพ์คอมเมนต์

  AssignmentComment({
    required this.commentId,
    required this.assignmentId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.commenterName,
  });

  factory AssignmentComment.fromJson(Map<String, dynamic> json) {
    // ดึงชื่อมาจาก object "user" ที่เราแนบมาด้วยจากฝั่ง Python
    final user = json['user'];
    final firstName = user != null ? (user['first_name'] ?? 'ไม่ระบุ') : 'ไม่ระบุ';
    final lastName = user != null ? (user['last_name'] ?? '') : '';

    return AssignmentComment(
      commentId: json['comment_id'] ?? '',
      assignmentId: json['assignment_id'] ?? '',
      userId: json['user_id'] ?? '',
      content: json['content'] ?? '',
      // แปลงเวลาที่ได้จากหลังบ้านให้เป็นเวลาท้องถิ่น (Local Time) ของเครื่อง
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']).toLocal() 
          : DateTime.now(),
      commenterName: '$firstName $lastName'.trim(),
    );
  }
}

// =======================================
// 2. คอมเมนต์ของหน้าประกาศ (Announcement)
// =======================================
class AnnouncementComment {
  final String commentId;
  final String announcementId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String commenterName;

  AnnouncementComment({
    required this.commentId,
    required this.announcementId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.commenterName,
  });

  factory AnnouncementComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final firstName = user != null ? (user['first_name'] ?? 'ไม่ระบุ') : 'ไม่ระบุ';
    final lastName = user != null ? (user['last_name'] ?? '') : '';

    return AnnouncementComment(
      commentId: json['comment_id'] ?? '',
      announcementId: json['announcement_id'] ?? '',
      userId: json['user_id'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']).toLocal() 
          : DateTime.now(),
      commenterName: '$firstName $lastName'.trim(),
    );
  }
}
