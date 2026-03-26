import 'package:flutter/material.dart';
import 'package:frontend/models/attendance_report.dart';
import 'package:frontend/models/attendance_report_detail.dart';
import 'package:frontend/services/attendance_report_service.dart';
import 'package:intl/intl.dart';

// เพิ่ม: ใช้ข้อมูลสมาชิกคลาสเพื่อ map studentId -> ชื่อผู้ใช้
import 'package:frontend/services/class_service.dart';
import 'package:frontend/models/users.dart';

class ClassReportTab extends StatefulWidget {
  final String classId;

  const ClassReportTab({super.key, required this.classId});

  @override
  State<ClassReportTab> createState() => _ClassReportTabState();
}

class _ClassReportTabState extends State<ClassReportTab> {
  bool _loading = true;
  bool _hasError = false;
  String _errorMsg = '';

  List<AttendanceReport> _reports = [];
  Map<String, dynamic>? _summary;

  // เพิ่ม: ดัชนีเก็บข้อมูลผู้ใช้ของนักเรียนในคลาสนี้
  final Map<String, User> _userIndex = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final reports = await AttendanceReportService.getClassReports(
        widget.classId,
      );
      final summary = await AttendanceReportService.getClassSummary(
        widget.classId,
      );

      // โหลดรายชื่อสมาชิกในคลาส (เพื่อแปลง studentId -> ชื่อ)
      try {
        final cls = await ClassService.getClassroomDetails(widget.classId);
        for (final u in cls.students) {
          _userIndex[u.userId] = u;
        }
      } catch (_) {
        // ถ้าดึงไม่ได้ ให้ปล่อยผ่าน ใช้ studentId เป็น fallback
      }

      setState(() {
        _reports = reports;
        _summary = summary;
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

  // แปลง studentId -> ชื่อที่สวยงาม (first last > username > email > studentId)
  String _displayName(String studentId) {
    final u = _userIndex[studentId];
    if (u != null) {
      final fn = (u.firstName ?? '').trim();
      final ln = (u.lastName ?? '').trim();
      final full = [fn, ln].where((s) => s.isNotEmpty).join(' ');
      if (full.isNotEmpty) return full;
      if ((u.username).isNotEmpty) return u.username;
      if ((u.email ?? '').isNotEmpty) return u.email!;
    }
    return studentId;
  }

  Future<void> _generateReport() async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กำลังสร้างรายงาน...')));

      await AttendanceReportService.generateClassReport(widget.classId);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('สร้างรายงานสำเร็จ')));

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
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
                onPressed: _loadData,
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ปุ่มสร้างรายงานใหม่
          ElevatedButton.icon(
            onPressed: _generateReport,
            icon: const Icon(Icons.refresh),
            label: const Text('สร้างรายงานใหม่'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 16),

          // สรุปภาพรวมคลาส
          if (_summary != null) _buildSummaryCard(),
          const SizedBox(height: 16),

          // รายการนักเรียน
          Text(
            'รายงานนักเรียนแต่ละคน',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),

          if (_reports.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'ยังไม่มีรายงาน กดปุ่ม "สร้างรายงานใหม่" เพื่อเริ่มต้น',
                  ),
                ),
              ),
            )
          else
            ..._reports.map((report) => _buildStudentReportCard(report)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final total = _summary?['total_students'] ?? 0;
    final avgRate = (_summary?['average_attendance_rate'] ?? 0.0).toDouble();
    final totalSessions = _summary?['total_sessions'] ?? 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'สรุปภาพรวมคลาส',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  icon: Icons.people,
                  label: 'นักเรียน',
                  value: '$total คน',
                  color: Colors.blue,
                ),
                _buildSummaryItem(
                  icon: Icons.event_note,
                  label: 'จำนวนครั้ง',
                  value: '$totalSessions ครั้ง',
                  color: Colors.orange,
                ),
                _buildSummaryItem(
                  icon: Icons.check_circle,
                  label: 'เข้าเรียนเฉลี่ย',
                  value: '${avgRate.toStringAsFixed(1)}%',
                  color: _getAttendanceColor(avgRate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStudentReportCard(AttendanceReport report) {
    final rate = report.attendanceRate;
    final color = _getAttendanceColor(rate);
    final name = _displayName(report.studentId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetailDialog(report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.2),
                    child: Icon(Icons.person, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // เปลี่ยนจาก Student ID -> แสดงชื่อ
                        Text(
                          'นักเรียน: $name',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'อัปเดต: ${_formatDate(report.generatedAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${rate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        _getAttendanceLabel(rate),
                        style: TextStyle(fontSize: 12, color: color),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    'เข้าเรียน',
                    report.attendedSessions,
                    Colors.green,
                  ),
                  _buildStatColumn('สาย', report.lateSessions, Colors.orange),
                  _buildStatColumn('ขาด', report.absentSessions, Colors.red),
                  _buildStatColumn(
                    'กลับก่อน',
                    report.leftEarlySessions,
                    Colors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
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
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return date;
    }
  }

  void _showDetailDialog(AttendanceReport report) {
    final name = _displayName(report.studentId);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'รายละเอียดการเข้าเรียน',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(height: 24),
              // เปลี่ยนให้เห็นชื่อแทนรหัส
              _buildDetailRow('นักเรียน', name),
              _buildDetailRow('ทั้งหมด', '${report.totalSessions} ครั้ง'),
              _buildDetailRow('เข้าเรียน', '${report.attendedSessions} ครั้ง'),
              _buildDetailRow('สาย', '${report.lateSessions} ครั้ง'),
              _buildDetailRow('ขาด', '${report.absentSessions} ครั้ง'),
              _buildDetailRow('กลับก่อน', '${report.leftEarlySessions} ครั้ง'),
              _buildDetailRow(
                'ตรวจสอบซ้ำ',
                '${report.reverifiedSessions} ครั้ง',
              ),
              _buildDetailRow(
                'อัตราเข้าเรียน',
                '${report.attendanceRate.toStringAsFixed(2)}%',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ปิด'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
