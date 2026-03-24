import 'package:flutter/material.dart';
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
    _futureDetails = AttendanceReportService.getClassDailyReports(
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
      case 'leftearly':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายงานนักเรียน')),
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
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: Icon(
                    Icons.access_time,
                    color: _statusColor(d.status),
                  ),
                  title: Text('สถานะ: ${d.status}'),
                  subtitle: Text('เวลาเช็คชื่อ: ${d.checkInTime ?? "-"}'),
                  trailing: d.isReverified
                      ? const Icon(Icons.verified, color: Colors.green)
                      : const Icon(Icons.timer_off, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
