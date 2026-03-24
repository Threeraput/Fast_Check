// File: lib/models/classroom.dart
import 'users.dart'; // ใช้ User ที่คุณมีอยู่แล้ว

class Classroom {
  final String? classId;
  final String? name;
  final String? code;
  final String? description; // << NEW ให้ตรงกับ backend
  final String? teacherId;
  final String? startTime; // ISO-8601 string (nullable)
  final String? endTime; // ISO-8601 string (nullable)
  final String? createdAt;
  final String? updatedAt; // << NEW
  final User? teacher;
  final List<User> students;

  Classroom({
    this.classId,
    this.name,
    this.code,
    this.description,
    this.teacherId,
    this.startTime,
    this.endTime,
    this.createdAt,
    this.updatedAt,
    this.teacher,
    this.students = const [],
  });

  factory Classroom.fromJson(Map<String, dynamic> json) {
    return Classroom(
      classId: json['class_id']?.toString(),
      name: json['name']?.toString(),
      code: json['code']?.toString(),
      description: json['description']?.toString(),
      teacherId: json['teacher_id']?.toString(),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      teacher: json['teacher'] == null
          ? null
          : User.fromJson(json['teacher'] as Map<String, dynamic>),
      students: (json['students'] as List? ?? [])
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'name': name,
      'code': code,
      'description': description,
      'teacher_id': teacherId,
      'start_time': startTime,
      'end_time': endTime,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'teacher': teacher?.toJson(),
      'students': students.map((e) => e.toJson()).toList(),
    };
  }
}

/// ---------- DTOs ตรง schema FastAPI ----------

class ClassroomCreate {
  final String name;
  final String? description; // << NEW
  final String? startTime; // ISO-8601
  final String? endTime; // ISO-8601

  ClassroomCreate({
    required this.name,
    this.description,
    this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    if (startTime != null) 'start_time': startTime,
    if (endTime != null) 'end_time': endTime,
  };
}

class ClassroomUpdate {
  final String? name;
  final String? description; // << NEW
  final String? startTime;
  final String? endTime;

  ClassroomUpdate({this.name, this.description, this.startTime, this.endTime});

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (description != null) 'description': description,
    if (startTime != null) 'start_time': startTime,
    if (endTime != null) 'end_time': endTime,
  };
}

class ClassroomJoin {
  final String code;
  ClassroomJoin(this.code);

  Map<String, dynamic> toJson() => {'code': code};
}
