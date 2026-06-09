class Attendance {
  final String attendanceId;
  final String sessionId;
  final String classId;
  final String studentId;
  final String status; // "present" | "absent" | "late" | "suspected"
  final String method; // "face+gps" | "re-verify" | "manual"
  final double? lat;
  final double? lon;
  final double? distanceMeters;
  final DateTime? verifiedAt;
  final DateTime? createdAt;
  final bool isManualOverride;

  Attendance({
    required this.attendanceId,
    required this.sessionId,
    required this.classId,
    required this.studentId,
    required this.status,
    required this.method,
    this.lat,
    this.lon,
    this.distanceMeters,
    this.verifiedAt,
    this.createdAt,
    this.isManualOverride = false,
  });

  factory Attendance.fromJson(Map<String, dynamic> j) {
    return Attendance(
      attendanceId: (j['attendance_id'] ?? '').toString(),
      sessionId: (j['session_id'] ?? '').toString(),
      classId: (j['class_id'] ?? '').toString(),
      studentId: (j['student_id'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      method: (j['method'] ?? 'unknown').toString(),
      lat: j['lat'] == null ? null : (j['lat'] as num).toDouble(),
      lon: j['lon'] == null ? null : (j['lon'] as num).toDouble(),
      distanceMeters: j['distance_meters'] == null
          ? null
          : (j['distance_meters'] as num).toDouble(),
      // แมปชื่อฟิลด์จาก Backend ให้ตรงกัน และใช้วิธีที่ปลอดภัยที่สุด
      verifiedAt: j['last_verified_at'] != null
          ? DateTime.tryParse(j['last_verified_at'].toString())
          : null,
      createdAt: j['check_in_time'] != null
          ? DateTime.tryParse(j['check_in_time'].toString())
          : null,
      isManualOverride: j['is_manual_override'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'attendance_id': attendanceId,
    'session_id': sessionId,
    'class_id': classId,
    'student_id': studentId,
    'status': status,
    'method': method,
    'lat': lat,
    'lon': lon,
    'distance_meters': distanceMeters,
    'verified_at': verifiedAt?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'is_manual_override': isManualOverride,
  };
}
