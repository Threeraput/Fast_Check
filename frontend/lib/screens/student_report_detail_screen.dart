import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_report_detail.dart';
import '../services/attendance_report_service.dart';

class StudentReportDetailScreen extends StatefulWidget {
  final String studentId;

  const StudentReportDetailScreen({super.key, required this.studentId});

  @override
  State<StudentReportDetailScreen> createState() =>
      _StudentReportDetailScreenState();
}

class _StudentReportDetailScreenState extends State<StudentReportDetailScreen> {
  late Future<List<AttendanceReportDetail>> _futureDetails;

  @override
  void initState() {
    super.initState();
    // ✅ เปลี่ยนมาใช้ API ตัวใหม่สำหรับดึงข้อมูลรายบุคคล
    _futureDetails = AttendanceReportService.getStudentDailyReports(
      widget.studentId,
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      case 'left_early':
      case 'leftearly':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "-";
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      return DateFormat('dd MMM yyyy HH:mm').format(dt);
    } catch (_) {
      return dateTimeStr;
    }
  }

  // ✅ ฟังก์ชันเปิดดูรูปเต็มจอ
  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติการเข้าเรียน (รายวัน)')),
      body: FutureBuilder<List<AttendanceReportDetail>>(
        future: _futureDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('ยังไม่มีข้อมูลรายวัน'));
          }

          final details = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: details.length,
            itemBuilder: (context, i) {
              final d = details[i];
              final sColor = _statusColor(d.status);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- ส่วนหัว: วันที่ และ สถานะ ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'วันที่: ${_formatDateTime(d.sessionStart ?? d.checkInTime).split(' ')[0]}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: sColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              d.status.toUpperCase(),
                              style: TextStyle(
                                color: sColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // --- ส่วนที่ 1: การเช็คชื่อต้นคาบ ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => d.faceImageUrl != null
                                ? _showImageDialog(d.faceImageUrl!)
                                : null,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: d.faceImageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        d.faceImageUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      color: Colors.grey,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'เช็คชื่อเข้าเรียน',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'เวลา: ${_formatDateTime(d.checkInTime)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // --- ส่วนที่ 2: สุ่มตรวจ (แสดงเฉพาะถ้ามี) ---
                      if (d.reverifyImageUrl != null || d.isReverified) ...[
                        const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => d.reverifyImageUrl != null
                                  ? _showImageDialog(d.reverifyImageUrl!)
                                  : null,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: d.reverifyImageUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          d.reverifyImageUrl!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.verified,
                                        color: Colors.blue,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.verified,
                                        color: Colors.blue,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'ตรวจสอบระหว่างคาบ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'เวลา: ${_formatDateTime(d.reverifyTime)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
