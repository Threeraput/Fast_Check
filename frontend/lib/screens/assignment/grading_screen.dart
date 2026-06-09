// lib/screens/grading_screen.dart
import 'package:flutter/material.dart';
import 'package:frontend/config.dart';
import 'package:frontend/models/classroom.dart';
import 'package:frontend/models/classwork.dart';
import 'package:frontend/models/users.dart';
import 'package:frontend/services/class_service.dart';
import 'package:frontend/services/classwork_simple_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String API_BASE_URL = AppConfig.uploadsfileUrl;
class GradingScreen extends StatefulWidget {
  final String assignmentId;
  final String title;
  final String? classId;

  const GradingScreen({
    super.key,
    required this.assignmentId,
    required this.title,
    this.classId,
  });

  @override
  State<GradingScreen> createState() => _GradingScreenState();
}

class _GradingScreenState extends State<GradingScreen> {
  late Future<List<ClassworkSubmission>> _future;
  final _scoreControllers = <String, TextEditingController>{};
  final Map<String, User> _userIndex = {};

  @override
  void initState() {
    super.initState();
    _future = ClassworkSimpleService.getSubmissionsForAssignment(
      widget.assignmentId,
    );
    _loadUsersIfNeeded();
  }

  Future<void> _loadUsersIfNeeded() async {
    if (widget.classId == null) return;
    try {
      final Classroom cls = await ClassService.getClassroomDetails(
        widget.classId!,
      );
      for (final u in cls.students) {
        _userIndex[u.userId] = u;
      }
      if (mounted) setState(() {});
    } catch (e) {
      print("Error loading users: $e");
    }
  }

  String _displayName(String studentId) {
    final u = _userIndex[studentId];
    if (u != null) {
      final fn = (u.firstName ?? '').trim();
      final ln = (u.lastName ?? '').trim();
      final full = [fn, ln].where((s) => s.isNotEmpty).join(' ');
      if (full.isNotEmpty) return full;
      if ((u.username).isNotEmpty) return u.username;
    }
    return studentId; // Fallback
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ClassworkSimpleService.getSubmissionsForAssignment(
        widget.assignmentId,
      );
    });
  }

  Future<void> _saveScore({
    required String assignmentId,
    required String studentId,
    required String score,
  }) async {
    try {
      final parsedScore = int.tryParse(score) ?? 0;
      await ClassworkSimpleService.gradeSubmissionForAssignment( // ใช้ฟังก์ชันฝั่ง Teacher
        assignmentId: assignmentId,
        studentId: studentId,
        score: parsedScore,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกคะแนนเรียบร้อย'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openSubmissionFile(String urlOrPath) async {
    final resolvedUrl = _resolveFileUrl(urlOrPath);
    final uri = Uri.tryParse(resolvedUrl);

    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการเปิดไฟล์: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('URL ไม่ถูกต้อง: $resolvedUrl')),
      );
    }
  }
  // เพิ่มตัวแปรเช็คสถานะการโหลด
  bool _isDownloading = false;

  // ฟังก์ชันดาวน์โหลดรายงานสำหรับงานชิ้นนี้
  Future<void> _downloadAssignmentReport() async {
    setState(() {
      _isDownloading = true; 
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String realToken = prefs.getString('accessToken') ?? ''; 
      
      if (realToken.isEmpty) {
        throw Exception("ไม่พบ Token กรุณาล็อกอินใหม่อีกครั้ง");
      }
      
      // เรียกใช้ Service ดาวน์โหลด (ใช้ assignmentId ของหน้านี้)
      // ไปใส่ไว้ในไฟล์ ClassworkSimpleService.dart ด้วยนะครับ
      await ClassworkSimpleService.exportAssignmentReport(widget.assignmentId, realToken);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ดาวน์โหลดและเปิดไฟล์สำเร็จ!'), backgroundColor: Colors.green),
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

  String _resolveFileUrl(String relativePath) {
    const base = API_BASE_URL; // ให้ตรงกับ API_BASE_URL ของคุณ
    var path = relativePath.trim();

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.contains('static/')) {
      path = path.replaceFirst('static/', '');
    }
    if (!path.startsWith('workpdf/')) {
      path = 'workpdf/$path';
    }
    return '$base/$path';
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy, HH:mm');
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ตรวจงานนักเรียน', style: TextStyle(fontSize: 16)),
            Text(widget.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        
        // เติมปุ่มดาวน์โหลดรายงานเข้าไปใน AppBar
        actions: [
          _isDownloading 
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: SizedBox(
                      width: 24, 
                      height: 24, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                    )
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'ดาวน์โหลดรายงาน (Excel)',
                  onPressed: _downloadAssignmentReport,
                ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ClassworkSubmission>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
            }
            if (snap.hasError) {
              return Center(child: Text('โหลดข้อมูลไม่สำเร็จ: ${snap.error}'));
            }
            final subs = snap.data ?? [];
            if (subs.isEmpty) {
              return const Center(child: Text('ยังไม่มีนักเรียนส่งงานชิ้นนี้ครับ', style: TextStyle(fontSize: 16, color: Colors.grey)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: subs.length,
              itemBuilder: (context, i) {
                final s = subs[i];
                final c = _scoreControllers.putIfAbsent(
                  s.submissionId ?? s.studentId, // กันเหนียวเผื่อ ID เป็น null
                  () => TextEditingController(text: s.score?.toString() ?? ''),
                );

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'นักเรียน: ${_displayName(s.studentId)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        if (s.submittedAt != null)
                          Text.rich(
                            TextSpan(
                              text: 'ส่งเมื่อ: ',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                              children: [
                                TextSpan(
                                  text: df.format(s.submittedAt!),
                                  style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            text: 'สถานะ: ',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            children: [
                              TextSpan(
                                text: s.submissionStatus.name.replaceAll('_', ' '), // ลบขีดล่างให้สวยงาม
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: s.submissionStatus.name.contains('Time') ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (s.contentUrl != null) ...[
                          FilledButton.tonalIcon(
                            onPressed: () => _openSubmissionFile(s.contentUrl!),
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                            label: const Text('เปิดไฟล์ PDF ที่ส่ง'),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: c,
                                decoration: InputDecoration(
                                  labelText: 'กรอกคะแนน',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.blueAccent),
                              onPressed: () {
                                _saveScore(
                                  assignmentId: widget.assignmentId,
                                  studentId: s.studentId,
                                  score: c.text,
                                );
                              },
                              child: const Text('บันทึก'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}