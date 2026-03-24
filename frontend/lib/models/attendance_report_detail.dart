class AttendanceReportDetail {
  final String reportId;
  final String sessionId;
  final String status;
  final String? checkInTime;
  final bool isReverified;

  AttendanceReportDetail({
    required this.reportId,
    required this.sessionId,
    required this.status,
    this.checkInTime,
    required this.isReverified,
  });

  factory AttendanceReportDetail.fromJson(Map<String, dynamic> json) {
    return AttendanceReportDetail(
      reportId: json['report_id'],
      sessionId: json['session_id'],
      status: json['status'] ?? 'Unknown',
      checkInTime: json['check_in_time'],
      isReverified: json['is_reverified'] ?? false,
    );
  }
}
