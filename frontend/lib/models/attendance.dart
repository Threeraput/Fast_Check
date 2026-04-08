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
  });

  factory Attendance.fromJson(Map<String, dynamic> j) {
    return Attendance(
      attendanceId: j['attendance_id'] as String,
      sessionId: j['session_id'] as String,
      classId: j['class_id'] as String,
      studentId: j['student_id'] as String,
      status: j['status'] as String,
      method: j['method'] as String,
      lat: j['lat'] == null ? null : (j['lat'] as num).toDouble(),
      lon: j['lon'] == null ? null : (j['lon'] as num).toDouble(),
      distanceMeters: j['distance_meters'] == null
          ? null
          : (j['distance_meters'] as num).toDouble(),
      verifiedAt: j['verified_at'] == null
          ? null
          : DateTime.parse(j['verified_at']),
      createdAt: j['created_at'] == null
          ? null
          : DateTime.parse(j['created_at']),
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
  };
}
