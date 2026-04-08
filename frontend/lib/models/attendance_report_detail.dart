// ไฟล์: attendance_report_detail.dart
class AttendanceReportDetail {
  final String reportId;
  final String sessionId;
  final String status;
  final String? checkInTime;
  final String? sessionStart;
  final bool isReverified;
  //  เพิ่ม 3 ฟิลด์นี้เข้ามารับข้อมูล 2 รูป
  final String? faceImageUrl;
  final String? reverifyImageUrl;
  final String? reverifyTime;

  AttendanceReportDetail({
    required this.reportId,
    required this.sessionId,
    required this.status,
    this.checkInTime,
    this.sessionStart,
    required this.isReverified,
    this.faceImageUrl,
    this.reverifyImageUrl,
    this.reverifyTime,
  });

  factory AttendanceReportDetail.fromJson(Map<String, dynamic> json) {
    return AttendanceReportDetail(
      reportId: json['report_id'] ?? '',
      sessionId: json['session_id'] ?? '',
      status: json['status'] ?? 'Unknown',
      checkInTime: json['check_in_time'],
      sessionStart: json['session_start'],
      isReverified: json['is_reverified'] ?? false,

      //  แมปค่าจาก JSON ที่มาจาก Backend
      faceImageUrl: json['face_image_url'],
      reverifyImageUrl: json['reverify_image_url'],
      reverifyTime: json['reverify_time'],
    );
  }
}
