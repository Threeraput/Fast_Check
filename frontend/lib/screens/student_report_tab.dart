import 'package:flutter/material.dart';
import 'package:frontend/models/attendance_report.dart';
import 'package:frontend/models/attendance_report_detail.dart';
import 'package:frontend/services/attendance_report_service.dart';
import 'package:intl/intl.dart';

// เพิ่ม: ใช้บริการคลาสเพื่อแปลง classId -> className
import 'package:frontend/services/class_service.dart';

class StudentReportTab extends StatefulWidget {
  const StudentReportTab({super.key});

  @override
  State<StudentReportTab> createState() => _StudentReportTabState();
}

class _StudentReportTabState extends State<StudentReportTab> {
  bool _loading = true;
  bool _hasError = false;
  String _errorMsg = '';

  List<AttendanceReport> _myReports = [];
  List<AttendanceReportDetail> _myDailyReports = [];

  // แผนที่ classId -> className เพื่อแสดงชื่อห้องแทน id
  final Map<String, String> _classNameById = {};

  @override
  void initState() {
    super.initState();
    _loadMyReports();
  }

  Future<void> _loadMyReports() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final reports = await AttendanceReportService.getMyReports();
      final dailyReports = await AttendanceReportService.getMyDailyReports();

      // โหลดรายชื่อคลาสที่นักเรียนอยู่ เพื่อ map classId -> className
      try {
        final joined = await ClassService.getJoinedClasses();
        for (final c in joined) {
          final cid = c.classId;
          if (cid != null && cid.isNotEmpty) {
            _classNameById[cid] = (c.name ?? c.code ?? cid);
          }
        }
      } catch (_) {
        // ถ้าดึงไม่ได้ ให้ fallback แสดง classId
      }

      setState(() {
        _myReports = reports;
        _myDailyReports = dailyReports;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMsg = e.toString();
        _loading = false;
      });
    }
  }

  // helper: แปลง classId เป็นชื่อคลาส (fallback เป็น id ถ้าไม่พบ)
  String _className(String classId) {
    return _classNameById[classId] ?? classId;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('เกิดข้อผิดพลาด: $_errorMsg'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMyReports,
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      );
    }

    if (_myReports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.description_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'ยังไม่มีรายงานการเข้าเรียน',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'รอครูสร้างรายงานให้ก่อนนะ',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadMyReports,
                icon: const Icon(Icons.refresh),
                label: const Text('รีเฟรช'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyReports,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'รายงานการเข้าเรียนของฉัน',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // การ์ดสรุปแต่ละวิชา (แสดงชื่อคลาสแทน classId)
          ..._myReports.map((report) => _buildReportCard(report)),

          const SizedBox(height: 24),

          // ประวัติรายวัน
          if (_myDailyReports.isNotEmpty) ...[
            Text(
              'ประวัติการเช็คชื่อรายวัน',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._myDailyReports.map((detail) => _buildDailyDetailCard(detail)),
          ],
        ],
      ),
    );
  }

  Widget _buildReportCard(AttendanceReport report) {
    final rate = report.attendanceRate;
    final color = _getAttendanceColor(rate);
    final className = _className(report.classId);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showDetailDialog(report),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // หัวข้อวิชา
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.school, color: color, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // แสดงชื่อคลาสแทน classId
                        Text(
                          'วิชา: $className',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'อัปเดตล่าสุด: ${_formatDate(report.generatedAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // อัตราเข้าเรียนแบบใหญ่
              Center(
                child: Column(
                  children: [
                    Text(
                      '${rate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      _getAttendanceLabel(rate),
                      style: TextStyle(
                        fontSize: 16,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // แถบความคืบหน้า
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: rate / 100,
                  backgroundColor: Colors.grey[200],
                  color: color,
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 16),

              // สถิติย่อย
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.event_available,
                    label: 'เข้าเรียน',
                    value: '${report.attendedSessions}',
                    color: Colors.green,
                  ),
                  _buildStatItem(
                    icon: Icons.schedule,
                    label: 'สาย',
                    value: '${report.lateSessions}',
                    color: Colors.orange,
                  ),
                  _buildStatItem(
                    icon: Icons.event_busy,
                    label: 'ขาด',
                    value: '${report.absentSessions}',
                    color: Colors.red,
                  ),
                  _buildStatItem(
                    icon: Icons.exit_to_app,
                    label: 'กลับก่อน',
                    value: '${report.leftEarlySessions}',
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ข้อมูลทั้งหมด
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ทั้งหมด ${report.totalSessions} ครั้ง',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDailyDetailCard(AttendanceReportDetail detail) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (detail.status.toLowerCase()) {
      case 'present':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'เข้าเรียน';
        break;
      case 'late':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = 'สาย';
        break;
      case 'absent':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'ขาด';
        break;
      case 'left_early':
        statusColor = Colors.purple;
        statusIcon = Icons.exit_to_app;
        statusText = 'กลับก่อน';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = detail.status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(
          statusText,
          style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // เดิม: แสดง Session ID / เวลา
            // ถ้าต้องการเพิ่มชื่อคลาสตรงนี้ ต้องมีข้อมูล mapping รายวันของ session -> classId -> className จาก backend
            if (detail.checkInTime != null)
              Text('เวลา: ${_formatDateTime(detail.checkInTime!)}'),
            if (detail.isReverified)
              const Text(
                '✓ ตรวจสอบซ้ำแล้ว',
                style: TextStyle(color: Colors.blue, fontSize: 12),
              ),
          ],
        ),
        trailing: detail.isReverified
            ? const Icon(Icons.verified, color: Colors.blue, size: 20)
            : null,
      ),
    );
  }

  Color _getAttendanceColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getAttendanceLabel(double rate) {
    if (rate >= 80) return 'ดีมาก';
    if (rate >= 60) return 'พอใช้';
    return 'ควรปรับปรุง';
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd MMM yyyy HH:mm', 'th').format(dt);
    } catch (_) {
      return date;
    }
  }

  String _formatDateTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dateTime;
    }
  }

  void _showDetailDialog(AttendanceReport report) {
    final className = _className(report.classId);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.assessment,
                    color: _getAttendanceColor(report.attendanceRate),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'รายละเอียดการเข้าเรียน',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const Divider(height: 24),
              // เปลี่ยนเป็นชื่อคลาสแทน classId
              _buildDetailRow('วิชา', className),
              _buildDetailRow('ทั้งหมด', '${report.totalSessions} ครั้ง'),
              _buildDetailRow(
                'เข้าเรียน',
                '${report.attendedSessions} ครั้ง',
                Colors.green,
              ),
              _buildDetailRow(
                'สาย',
                '${report.lateSessions} ครั้ง',
                Colors.orange,
              ),
              _buildDetailRow(
                'ขาด',
                '${report.absentSessions} ครั้ง',
                Colors.red,
              ),
              _buildDetailRow(
                'กลับก่อน',
                '${report.leftEarlySessions} ครั้ง',
                Colors.purple,
              ),
              _buildDetailRow(
                'ตรวจสอบซ้ำ',
                '${report.reverifiedSessions} ครั้ง',
                Colors.blue,
              ),
              const Divider(height: 24),
              _buildDetailRow(
                'อัตราเข้าเรียน',
                '${report.attendanceRate.toStringAsFixed(2)}%',
                _getAttendanceColor(report.attendanceRate),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('ปิด'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
