class AttendanceReport {
  final String reportId;
  final String classId;
  final String studentId;
  final int totalSessions;
  final int attendedSessions;
  final int lateSessions;
  final int absentSessions;
  final int leftEarlySessions;
  final int reverifiedSessions;
  final double attendanceRate;
  final String generatedAt;

  AttendanceReport({
    required this.reportId,
    required this.classId,
    required this.studentId,
    required this.totalSessions,
    required this.attendedSessions,
    required this.lateSessions,
    required this.absentSessions,
    required this.leftEarlySessions,
    required this.reverifiedSessions,
    required this.attendanceRate,
    required this.generatedAt,
  });

  factory AttendanceReport.fromJson(Map<String, dynamic> json) {
    return AttendanceReport(
      reportId: json['report_id'],
      classId: json['class_id'],
      studentId: json['student_id'],
      totalSessions: json['total_sessions'] ?? 0,
      attendedSessions: json['attended_sessions'] ?? 0,
      lateSessions: json['late_sessions'] ?? 0,
      absentSessions: json['absent_sessions'] ?? 0,
      leftEarlySessions: json['left_early_sessions'] ?? 0,
      reverifiedSessions: json['reverified_sessions'] ?? 0,
      attendanceRate: (json['attendance_rate'] ?? 0).toDouble(),
      generatedAt: json['generated_at'] ?? '',
    );
  }
}
