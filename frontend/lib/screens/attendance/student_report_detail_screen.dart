import 'package:flutter/material.dart';
import 'package:frontend/services/user_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/attendance_service.dart';
import 'package:frontend/widgets/attendance_status_badge.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_report_detail.dart';
import '../../services/attendance_report_service.dart';

class StudentReportDetailScreen extends StatefulWidget {
  final String studentId;
  final String? classId;

  const StudentReportDetailScreen({
    super.key,
    required this.studentId,
    this.classId,
  });

  @override
  State<StudentReportDetailScreen> createState() =>
      _StudentReportDetailScreenState();
}

class _StudentReportDetailScreenState extends State<StudentReportDetailScreen> {
  late Future<List<AttendanceReportDetail>> _futureDetails;
  bool _isTeacher = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkRole();
  }

  void _loadData() {
    setState(() {
      _futureDetails = AttendanceReportService.getStudentDailyReports(
        widget.studentId,
        classId: widget.classId,
      );
    });
  }

  Future<void> _checkRole() async {
    final roles = await AuthService.getTokenRoles();
    if (mounted) {
      setState(() {
        _isTeacher = roles.contains('teacher') || roles.contains('admin');
      });
    }
  }

  void _showOverrideSheet(AttendanceReportDetail detail) {
    if (!_isTeacher) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'แก้ไขสถานะการเข้าเรียน',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('มาเรียน (Present)'),
              onTap: () => _confirmUpdateStatus(detail, 'Present'),
            ),
            ListTile(
              leading: const Icon(Icons.access_time, color: Colors.orange),
              title: const Text('สาย (Late)'),
              onTap: () => _confirmUpdateStatus(detail, 'Late'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text('ขาด (Absent)'),
              onTap: () => _confirmUpdateStatus(detail, 'Absent'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _confirmUpdateStatus(AttendanceReportDetail detail, String newStatus) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการแก้ไขสถานะ'),
        content: Text(
          'คุณต้องการเปลี่ยนสถานะการเข้าเรียนเป็น "$newStatus" ใช่หรือไม่?\n\n',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(detail, newStatus);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
    AttendanceReportDetail detail,
    String newStatus,
  ) async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กำลังบันทึกการแก้ไข...')));

      await AttendanceService.manualOverride(
        sessionId: detail.sessionId,
        studentId: widget.studentId,
        newStatus: newStatus,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('แก้ไขสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "-";
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return dateTimeStr;
    }
  }

  String _formatDateOnly(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "ไม่ระบุวันที่";
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return "ไม่ระบุวันที่";
    }
  }

  Map<String, List<AttendanceReportDetail>> _groupByDate(
    List<AttendanceReportDetail> details,
  ) {
    final map = <String, List<AttendanceReportDetail>>{};
    for (var d in details) {
      final dateStr = d.sessionStart ?? d.checkInTime;
      final key = _formatDateOnly(dateStr);

      if (!map.containsKey(key)) {
        map[key] = [];
      }
      map[key]!.add(d);
    }

    for (final entry in map.entries) {
      entry.value.sort((a, b) {
        final at = _sortDateTime(a);
        final bt = _sortDateTime(b);
        return bt.compareTo(at);
      });
    }

    return map;
  }

  DateTime _sortDateTime(AttendanceReportDetail d) {
    final raw = d.checkInTime ?? d.sessionStart;
    if (raw == null || raw.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
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

          final groupedDetails = _groupByDate(snapshot.data!);
          final dateKeys = groupedDetails.keys.toList();

          dateKeys.sort((a, b) {
            final aItems = groupedDetails[a] ?? [];
            final bItems = groupedDetails[b] ?? [];
            final aTop = aItems.isNotEmpty
                ? _sortDateTime(aItems.first)
                : DateTime.fromMillisecondsSinceEpoch(0);
            final bTop = bItems.isNotEmpty
                ? _sortDateTime(bItems.first)
                : DateTime.fromMillisecondsSinceEpoch(0);
            return bTop.compareTo(aTop);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: dateKeys.length,
            itemBuilder: (context, index) {
              final dateKey = dateKeys[index];
              final dailyItems = groupedDetails[dateKey]!;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: index == 0,
                  backgroundColor: Colors.blue.shade50.withValues(alpha: 0.2),
                  title: Text(
                    'วันที่: $dateKey',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '${dailyItems.length} คาบเรียน',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  children: dailyItems.map((d) {
                    return InkWell(
                      onTap: () => _showOverrideSheet(d),
                      child: Container(
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
                                AttendanceStatusBadge(
                                  status: d.status,
                                  isManualOverride: d.isManualOverride,
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (d.faceImageUrl != null) {
                                      final validUrl =
                                          UserService.absoluteAvatarUrl(
                                            d.faceImageUrl,
                                          );
                                      if (validUrl != null) {
                                        _showImageDialog(validUrl);
                                      }
                                    }
                                  },
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
                                              UserService.absoluteAvatarUrl(
                                                    d.faceImageUrl,
                                                  ) ??
                                                  '',
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => const Icon(
                                                    Icons.person,
                                                    color: Colors.grey,
                                                  ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'เช็คชื่อ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
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
                            if (d.reverifyImageUrl != null ||
                                d.isReverified) ...[
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (d.reverifyImageUrl != null) {
                                        final validUrl =
                                            UserService.absoluteAvatarUrl(
                                              d.reverifyImageUrl,
                                            );
                                        if (validUrl != null) {
                                          _showImageDialog(validUrl);
                                        }
                                      }
                                    },
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: d.reverifyImageUrl != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                UserService.absoluteAvatarUrl(
                                                      d.reverifyImageUrl,
                                                    ) ??
                                                    '',
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => const Icon(
                                                      Icons.verified,
                                                      color: Colors.blue,
                                                    ),
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
                                        // Removed 'ตรวจสอบซ้ำ' label as requested
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
