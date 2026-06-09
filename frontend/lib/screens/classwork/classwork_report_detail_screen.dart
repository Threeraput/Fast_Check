import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../models/classwork.dart';
import '../../services/classwork_simple_service.dart';
import '../../config.dart';

class ClassworkReportDetailScreen extends StatefulWidget {
  final String studentId;
  final String classId;
  final String userRole; // 'student' or 'teacher'

  const ClassworkReportDetailScreen({
    super.key,
    required this.studentId,
    required this.classId,
    required this.userRole,
  });

  @override
  State<ClassworkReportDetailScreen> createState() =>
      _ClassworkReportDetailScreenState();
}

class _ClassworkReportDetailScreenState
    extends State<ClassworkReportDetailScreen> {
  late Future<List<AssignmentWithMySubmission>> _futureAssignments;

  @override
  void initState() {
    super.initState();
    _futureAssignments = _loadAssignments();
  }

  Future<List<AssignmentWithMySubmission>> _loadAssignments() async {
    List<dynamic> rawData;

    if (widget.userRole == 'teacher') {
      // ครูเรียก API สำหรับครู - ดูงานที่นักเรียนส่งในคลาส
      rawData = await ClassworkSimpleService.getStudentSubmissionsForClass(
        widget.classId,
        widget.studentId,
      );
    } else {
      // นักเรียนเรียก API สำหรับนักเรียน - ดึงรายการงานและสถานะการส่ง
      rawData = await ClassworkSimpleService.getStudentAssignments(
        widget.classId,
      );
    }

    return rawData.map((j) => AssignmentWithMySubmission.fromJson(j)).toList();
  }

  Color _statusColor(SubmissionLateness status) {
    switch (status) {
      case SubmissionLateness.onTime:
        return Colors.green;
      case SubmissionLateness.late:
        return Colors.orange;
      case SubmissionLateness.notSubmitted:
        return Colors.red;
    }
  }

  String _statusText(SubmissionLateness status) {
    switch (status) {
      case SubmissionLateness.onTime:
        return 'ส่งตรงเวลา';
      case SubmissionLateness.late:
        return 'ส่งช้า';
      case SubmissionLateness.notSubmitted:
        return 'ยังไม่ส่ง';
    }
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return "-";
    try {
      return DateFormat('dd MMM yyyy').format(dateTime);
    } catch (_) {
      return dateTime.toString();
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return "-";
    try {
      return DateFormat('dd MMM yyyy HH:mm').format(dateTime);
    } catch (_) {
      return dateTime.toString();
    }
  }

  // ฟังก์ชันจัดกลุ่มตามวันที่ due_date
  Map<String, List<AssignmentWithMySubmission>> _groupByDueDate(
    List<AssignmentWithMySubmission> assignments,
  ) {
    final map = <String, List<AssignmentWithMySubmission>>{};
    for (var a in assignments) {
      final key = _formatDate(a.dueDate);
      if (!map.containsKey(key)) {
        map[key] = [];
      }
      map[key]!.add(a);
    }
    return map;
  }

  // ดาวน์โหลดและเปิดไฟล์ PDF
  Future<void> _openPdf(String? contentUrl) async {
    if (contentUrl == null || contentUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่พบไฟล์ PDF')));
      return;
    }

    try {
      // สร้าง URL เต็ม
      final pdfUrl = '${AppConfig.uploadsfileUrl}/$contentUrl';

      // แสดง loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // ดาวน์โหลดไฟล์
      final response = await http.get(Uri.parse(pdfUrl));

      if (!mounted) return;
      Navigator.pop(context); // ปิด loading

      if (response.statusCode == 200) {
        // บันทึกไฟล์ชั่วคราว
        final tempDir = await getTemporaryDirectory();
        final fileName = contentUrl.split('/').last;
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        // เปิดไฟล์
        await OpenFilex.open(file.path);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถดาวน์โหลดไฟล์: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // ปิด loading กรณี error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติการส่งงาน')),
      body: FutureBuilder<List<AssignmentWithMySubmission>>(
        future: _futureAssignments,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('ยังไม่มีงาน'));
          }

          // จัดกลุ่มตามวันที่ส่ง
          final groupedAssignments = _groupByDueDate(snapshot.data!);
          final dateKeys = groupedAssignments.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: dateKeys.length,
            itemBuilder: (context, index) {
              final dateKey = dateKeys[index];
              final assignments = groupedAssignments[dateKey]!;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: index == 0,
                  backgroundColor: Colors.blue.shade50.withOpacity(0.2),
                  title: Text(
                    'กำหนดส่ง: $dateKey',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '${assignments.length} งาน',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  children: assignments.map((a) {
                    final sColor = _statusColor(a.computedStatus);
                    final submission = a.mySubmission;

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
                          // --- ชื่องาน ---
                          Text(
                            a.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // --- คะแนนเต็ม ---
                          Text(
                            'คะแนนเต็ม: ${a.maxScore}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          const Divider(height: 16),

                          // --- สถานะการส่ง ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'สถานะ:',
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
                                  _statusText(a.computedStatus),
                                  style: TextStyle(
                                    color: sColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // --- ข้อมูลการส่ง (ถ้ามี) ---
                          if (submission != null) ...[
                            const SizedBox(height: 12),

                            // --- เวลาส่ง ---
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ส่งเมื่อ: ${_formatDateTime(submission.submittedAt)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),

                            // --- คะแนน (ถ้าตรวจแล้ว) ---
                            if (submission.graded) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.grade,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'คะแนน: ${submission.score}/${a.maxScore}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // --- ปุ่มเปิด PDF ---
                            if (submission.contentUrl != null) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _openPdf(submission.contentUrl),
                                  icon: const Icon(
                                    Icons.picture_as_pdf,
                                    size: 18,
                                  ),
                                  label: const Text('เปิดไฟล์ PDF'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade400,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            // ยังไม่ส่ง - แสดงข้อความ
                            const SizedBox(height: 8),
                            Text(
                              'ยังไม่ได้ส่งงาน',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                              ),
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

/// ===============================
/// Model สำหรับ API Response
/// ===============================

class AssignmentWithMySubmission {
  final String assignmentId;
  final String classId;
  final String teacherId;
  final String title;
  final int maxScore;
  final DateTime dueDate;
  final SubmissionLateness computedStatus;
  final MySubmission? mySubmission;

  AssignmentWithMySubmission({
    required this.assignmentId,
    required this.classId,
    required this.teacherId,
    required this.title,
    required this.maxScore,
    required this.dueDate,
    required this.computedStatus,
    this.mySubmission,
  });

  factory AssignmentWithMySubmission.fromJson(Map<String, dynamic> j) {
    return AssignmentWithMySubmission(
      assignmentId: j['assignment_id']?.toString() ?? '',
      classId: j['class_id']?.toString() ?? '',
      teacherId: j['teacher_id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      maxScore: (j['max_score'] is num)
          ? (j['max_score'] as num).toInt()
          : (j['max_score'] as int? ?? 100),
      dueDate:
          DateTime.tryParse(j['due_date']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      computedStatus: latenessFromString(j['computed_status']?.toString()),
      mySubmission: j['my_submission'] != null
          ? MySubmission.fromJson(j['my_submission'])
          : null,
    );
  }
}

class MySubmission {
  final String? contentUrl;
  final DateTime? submittedAt;
  final SubmissionLateness submissionStatus;
  final bool graded;
  final int? score;

  MySubmission({
    this.contentUrl,
    this.submittedAt,
    required this.submissionStatus,
    required this.graded,
    this.score,
  });

  factory MySubmission.fromJson(Map<String, dynamic> j) {
    return MySubmission(
      contentUrl: j['content_url']?.toString(),
      submittedAt: j['submitted_at'] != null
          ? DateTime.tryParse(j['submitted_at'].toString())?.toLocal()
          : null,
      submissionStatus: latenessFromString(j['submission_status']?.toString()),
      graded: j['graded'] == true,
      score: (j['score'] is num)
          ? (j['score'] as num).toInt()
          : (j['score'] as int?),
    );
  }
}
