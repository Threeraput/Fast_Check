import 'package:flutter/material.dart';
import 'package:frontend/models/attendance_report.dart';
import 'package:frontend/screens/classwork/classwork_report_detail_screen.dart';
import 'package:frontend/services/attendance_report_service.dart';
import 'package:frontend/services/classwork_simple_service.dart'; // เพิ่ม import นี้
import 'package:shared_preferences/shared_preferences.dart';
import 'student_report_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:frontend/utils/app_theme.dart';
import 'package:frontend/services/user_service.dart';
import 'package:frontend/widgets/glass_card.dart';

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

  // เพิ่มสถานะสำหรับการดาวน์โหลด
  bool _isDownloading = false;

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

      // โหลดรายชื่อสมาชิกในคลาส (เพื่อแปลง studentId -> ชื่อ/รูป)
      try {
        final cls = await ClassService.getClassroomMembers(widget.classId);
        for (final u in cls.students) {
          _userIndex[u.userId] = u;
          final sid = (u.studentId ?? '').trim();
          if (sid.isNotEmpty) {
            _userIndex[sid] = u;
          }
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
    final key = studentId.trim();
    final u = _userIndex[key] ?? _userIndex[studentId];
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

  Widget _studentAvatar(String studentId, Color accent) {
    final key = studentId.trim();
    final u = _userIndex[key] ?? _userIndex[studentId];
    final imageUrl = u != null ? UserService.absoluteAvatarUrl(u.avatarUrl) : null;
    final display = _displayName(studentId).trim();
    final initial = display.isNotEmpty ? display.substring(0, 1).toUpperCase() : '?';
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: accent.withValues(alpha: 0.15),
        foregroundImage: NetworkImage(imageUrl),
        child: Text(
          initial,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: accent.withValues(alpha: 0.2),
      child: Text(
        initial,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
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

  Future<void> _showExportOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'เลือกประเภทการส่งออก (Excel)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
                title: const Text('รายงานการเข้าเรียนรายวัน'),
                subtitle: const Text('สรุปการเช็คชื่อของนักเรียนทุกคน'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadAttendanceReport();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.assignment_outlined,
                  color: Colors.blue,
                ),
                title: const Text('สถิติการส่งงานของคลาส'),
                subtitle: const Text('สรุปคะแนนและสถานะการส่งงานทุกชิ้น'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadClassworkStats();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadAttendanceReport() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String realToken = prefs.getString('accessToken') ?? '';

      if (realToken.isEmpty) {
        throw Exception("ไม่พบ Token กรุณาล็อกอินใหม่อีกครั้ง");
      }

      await AttendanceReportService.exportDetailedReport(
        widget.classId,
        realToken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ดาวน์โหลดรายงานการเข้าเรียนสำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _downloadClassworkStats() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String realToken = prefs.getString('accessToken') ?? '';

      if (realToken.isEmpty) {
        throw Exception("ไม่พบ Token กรุณาล็อกอินใหม่อีกครั้ง");
      }

      await ClassworkSimpleService.exportClassworkOverallStats(
        widget.classId,
        realToken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ดาวน์โหลดสถิติงานสำเร็จ!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
        padding: const EdgeInsets.all(12),
        children: [
          _buildRoleDivider(
            label: 'Teacher Report',
            color: const Color(0xFF2563EB),
            icon: Icons.school,
          ),
          const SizedBox(height: 12),

          // ปุ่มดาวน์โหลดรายงาน (Excel)
          ElevatedButton.icon(
            onPressed: _isDownloading
                ? null
                : _showExportOptions, // เปลี่ยนจาก _downloadReport เป็น _showExportOptions
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download, color: Colors.white),
            label: Text(
              _isDownloading ? 'กำลังดาวน์โหลด...' : 'ดาวน์โหลดรายงาน (Excel)',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              minimumSize: const Size.fromHeight(42),
            ),
          ),

          const SizedBox(height: 16),

          // สรุปภาพรวมคลาส
          if (_summary != null) _buildSummaryCard(),
          const SizedBox(height: 16),

          // รายการนักเรียน
          Text(
            'รายงานนักเรียนแต่ละคน',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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

  Widget _buildRoleDivider({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.0), color.withValues(alpha: 0.75)],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.25,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.75), color.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final total = _summary?['total_students'] ?? 0;
    final avgRate = (_summary?['average_attendance_rate'] ?? 0.0).toDouble();
    final totalSessions = _summary?['total_sessions'] ?? 0;

    return GlassCard(
      accent: const Color(0xFF2563EB),
      radius: 16,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'สรุปภาพรวมคลาส',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const Divider(height: 20),
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
        Icon(icon, size: 26, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        accent: color,
        radius: 16,
        onTap: () => _showDetailDialog(report),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _studentAvatar(report.studentId, color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // เปลี่ยนจาก Student ID -> แสดงชื่อ
                        Text(
                          'นักเรียน: $name',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
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
                            fontSize: 17,
                          fontWeight: FontWeight.w700,
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
              const Divider(height: 20),
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
            fontSize: 15,
            fontWeight: FontWeight.w700,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: GlassCard(
          accent: _getAttendanceColor(report.attendanceRate),
          radius: 16,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'รายละเอียดการเข้าเรียน',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Divider(height: 20),
              _buildDetailRow('นักเรียน', name),
              _buildDetailRow('ทั้งหมด', '${report.totalSessions} ครั้ง'),
              _buildDetailRow('เข้าเรียน', '${report.attendedSessions} ครั้ง'),
              _buildDetailRow('สาย', '${report.lateSessions} ครั้ง'),
              _buildDetailRow('ขาด', '${report.absentSessions} ครั้ง'),
              _buildDetailRow('กลับก่อน', '${report.leftEarlySessions} ครั้ง'),
              // Removed 'ตรวจสอบซ้ำ' row as requested
              _buildDetailRow(
                'อัตราเข้าเรียน',
                '${report.attendanceRate.toStringAsFixed(2)}%',
              ),
              const SizedBox(height: 16),

              // เพิ่มปุ่มนี้เข้าไป เพื่อให้ครูกดไปหน้าดูรูป
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // ปิด Dialog
                    // import หน้าต่างนี้ไว้ด้านบนไฟล์ด้วยนะครับ ถ้ายังไม่มี
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            // ไปที่ไฟล์ student_report_detail_screen.dart
                            StudentReportDetailScreen(
                              studentId: report.studentId,
                              classId: widget.classId, // 👈 ส่ง classId ไปด้วย
                            ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text('ดูประวัติรายวันและรูปถ่าย'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(40),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // เพิ่มปุ่มนี้เข้าไป เพื่อให้ครูกดไปหน้าดูรูป
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // ปิด Dialog
                    // import หน้าต่างนี้ไว้ด้านบนไฟล์ด้วยนะครับ ถ้ายังไม่มี
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            // ไปที่ไฟล์ student_report_detail_screen.dart
                            ClassworkReportDetailScreen(
                              studentId: report.studentId,
                              classId: report.classId, // เพิ่ม classId
                              userRole: 'teacher', // กำหนดเป็น teacher
                            ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.assignment),
                  label: const Text('ดูประวัติการส่งงาน'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(40),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'ปิด',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
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
