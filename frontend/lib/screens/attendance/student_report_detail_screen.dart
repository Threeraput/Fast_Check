import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_report_detail.dart';
import '../../services/attendance_report_service.dart';

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

  String _statusText(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return 'เข้าเรียน';
      case 'late':
        return 'สาย';
      case 'absent':
        return 'ขาด';
      case 'left_early':
      case 'leftearly':
        return 'กลับก่อน';
      default:
        return status;
    }
  }

  String _formatTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "-";
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      return DateFormat('HH:mm').format(dt); // โชว์แค่เวลา (ชั่วโมง:นาที)
    } catch (_) {
      return dateTimeStr;
    }
  }

  // 1. ฟังก์ชันจัดกลุ่ม: ดึงมาเฉพาะ "วัน เดือน ปี"
  String _formatDateOnly(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "ไม่ระบุวันที่";
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      // จะได้รูปแบบเช่น: 27 Mar 2026 หรือ 27/03/2026
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return "ไม่ระบุวันที่";
    }
  }

  // 2. ฟังก์ชันจัดกลุ่มข้อมูลแยกตาม "วันที่"
  Map<String, List<AttendanceReportDetail>> _groupByDate(
    List<AttendanceReportDetail> details,
  ) {
    final map = <String, List<AttendanceReportDetail>>{};
    for (var d in details) {
      final dateStr = d.sessionStart ?? d.checkInTime;
      final key = _formatDateOnly(dateStr); // ใช้ฟังก์ชันดึงเฉพาะวันที่เป็น Key

      if (!map.containsKey(key)) {
        map[key] = [];
      }
      map[key]!.add(d);
    }
    return map;
  }

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

          // นำข้อมูลมาจัดกลุ่มตาม "วันที่"
          final groupedDetails = _groupByDate(snapshot.data!);
          final dateKeys = groupedDetails.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: dateKeys.length,
            itemBuilder: (context, index) {
              final dateKey = dateKeys[index];
              final dailyItems = groupedDetails[dateKey]!;

              // การ์ดแบบพับได้ (แยกตามวันที่)
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: index == 0, // กางของวันล่าสุดไว้เสมอ
                  backgroundColor: Colors.blue.shade50.withOpacity(0.2),
                  title: Text(
                    'วันที่: $dateKey', // หัวข้อคือวันที่ เช่น วันที่: 27 Mar 2026
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '${dailyItems.length} คาบเรียน',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),

                  // ข้อมูลของแต่ละคาบในวันนั้น
                  children: dailyItems.map((d) {
                    final sColor = _statusColor(d.status);

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- สถานะของคาบเรียน ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'ผลการเช็คชื่อ:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                                  _statusText(d.status),
                                  style: TextStyle(
                                    color: sColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),

                          // --- รูป 1: เช็คชื่อ ---
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => d.faceImageUrl != null
                                    ? _showImageDialog(d.faceImageUrl!)
                                    : null,
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: d.faceImageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'เช็คชื่อ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    // ใช้เวลา (HH:mm) แทนการโชว์วันที่ซ้ำ
                                    Text(
                                      'เวลา: ${_formatTime(d.checkInTime)} น.',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // --- รูป 2: สุ่มตรวจ (ถ้ามี) ---
                          if (d.reverifyImageUrl != null || d.isReverified) ...[
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => d.reverifyImageUrl != null
                                      ? _showImageDialog(d.reverifyImageUrl!)
                                      : null,
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: d.reverifyImageUrl != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ตรวจสอบซ้ำ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                          fontSize: 13,
                                        ),
                                      ),
                                      // ใช้เวลา (HH:mm) แทนการโชว์วันที่ซ้ำ
                                      Text(
                                        'เวลา: ${_formatTime(d.reverifyTime)} น.',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
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
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
