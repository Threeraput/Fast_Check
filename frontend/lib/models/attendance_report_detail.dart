class AttendanceReportDetail {
  final String reportId;
  final String sessionId;
  final String status;
  final String? checkInTime;
  // --- เพิ่มฟิลด์นี้ ---
  final String? sessionStart;
  // -------------------
  final bool isReverified;

  AttendanceReportDetail({
    required this.reportId,
    required this.sessionId,
    required this.status,
    this.checkInTime,
    this.sessionStart,
    required this.isReverified,
  });

  factory AttendanceReportDetail.fromJson(Map<String, dynamic> json) {
    return AttendanceReportDetail(
      reportId: json['report_id'] ?? '',
      sessionId: json['session_id'] ?? '',
      status: json['status'] ?? 'Unknown',
      checkInTime: json['check_in_time'],
      // รับค่าเวลาเริ่ม Session จาก Backend
      sessionStart: json['session_start'],
      isReverified: json['is_reverified'] ?? false,
    );
  }
}
