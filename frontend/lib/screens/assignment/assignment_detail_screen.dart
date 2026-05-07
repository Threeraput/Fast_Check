import 'package:flutter/material.dart';
import 'package:frontend/models/classroom.dart';
import 'package:frontend/models/classwork.dart';
import 'package:frontend/models/comment_model.dart';
import 'package:frontend/services/class_service.dart';
import 'package:frontend/services/classwork_simple_service.dart';
import 'package:intl/intl.dart';
import 'package:frontend/screens/assignment/grading_screen.dart';

class AssignmentDetailScreen extends StatefulWidget {
  final String assignmentId;
  final String title;
  final String? classId;
  final bool isTeacher;

  const AssignmentDetailScreen({
    super.key,
    required this.assignmentId,
    required this.title,
    this.classId,
    this.isTeacher = false,
  });

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

// เพิ่ม SingleTickerProviderStateMixin สำหรับใช้งาน TabController
class _AssignmentDetailScreenState extends State<AssignmentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<AssignmentComment> _comments = [];
  bool _isLoadingComments = true;
  final TextEditingController _commentController = TextEditingController();

  List<ClassworkSubmission> _submissions = [];
  bool _isLoadingSubmissions = true;
  Classroom? _classroom;
  bool _isLoadingClassroom = false;
  bool _isAccepting = true;

  @override
  void initState() {
    super.initState();
    // ถ้าเป็นครูให้มี 2 แท็บ (Instructions, Student Work) ถ้าเป็นนักเรียนมีแค่ 1 แท็บ
    _tabController = TabController(
      length: widget.isTeacher ? 2 : 1,
      vsync: this,
    );
    _fetchComments();

    if (widget.isTeacher) {
      _fetchStudentSubmissions();
    }
    if (widget.classId != null) {
      _fetchClassroomMembers();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final comments = await ClassworkSimpleService.getComments(
        widget.assignmentId,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingComments = false);
      print("Error fetching comments: $e");
    }
  }

  Future<void> _fetchStudentSubmissions() async {
    if (!widget.isTeacher) return;

    setState(() {
      _isLoadingSubmissions = true;
    });

    try {
      final submissions =
          await ClassworkSimpleService.getSubmissionsForAssignment(
            widget.assignmentId,
          );
      if (mounted) {
        setState(() {
          _submissions = submissions;
          _isLoadingSubmissions = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSubmissions = false);
      print("Error fetching student submissions: $e");
    }
  }

  Future<void> _fetchClassroomMembers() async {
    if (widget.classId == null) return;

    setState(() {
      _isLoadingClassroom = true;
    });

    try {
      final classroom = await ClassService.getClassroomMembers(widget.classId!);
      if (mounted) {
        setState(() {
          _classroom = classroom;
          _isLoadingClassroom = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingClassroom = false);
      print("Error fetching classroom members: $e");
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    FocusScope.of(context).unfocus();

    try {
      await ClassworkSimpleService.addComment(
        assignmentId: widget.assignmentId,
        content: text,
      );
      _fetchComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ส่งคอมเมนต์ไม่สำเร็จ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        // เพิ่ม TabBar ไว้ด้านล่างของ AppBar
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.blueAccent,
          tabs: [
            const Tab(text: 'Instructions'),
            if (widget.isTeacher) const Tab(text: 'Student Work'),
          ],
        ),
      ),
      // ใช้ TabBarView เพื่อสลับหน้าจอตามแท็บ
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInstructionsTab(),
          if (widget.isTeacher) _buildStudentWorkTab(),
        ],
      ),
    );
  }

  // ==========================================
  // แท็บที่ 1: Instructions (รายละเอียดงาน + คอมเมนต์)
  // ==========================================
  Widget _buildInstructionsTab() {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchComments,
            child: ListView.builder(
              itemCount: 1 + _comments.length,
              itemBuilder: (context, index) {
                // ส่วนหัว (รายละเอียดงาน)
                if (index == 0) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.assignment,
                                color: Colors.blueAccent,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '100 points • ครบกำหนด: ไม่ระบุ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Class comments (${_comments.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // ส่วนคอมเมนต์
                if (_isLoadingComments && index == 1) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final comment = _comments[index - 1];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Text(
                          comment.commenterName.isNotEmpty
                              ? comment.commenterName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  comment.commenterName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat(
                                    'dd MMM HH:mm',
                                  ).format(comment.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              comment.content,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // กล่องพิมพ์คอมเมนต์ด้านล่าง
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, -2),
                blurRadius: 5,
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Add class comment...",
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _sendComment,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 👥 แท็บที่ 2: Student Work (หน้าดูคนส่งงานและตรวจงาน)
  // ==========================================
  Widget _buildStudentWorkTab() {
    final int turnedInCount = _submissions.length;
    final int assignedCount = _classroom?.students.length ?? 0;

    return Column(
      children: [
        // (Turned in / Assigned)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn(turnedInCount.toString(), 'Turned in'),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.shade300,
              ), // เส้นคั่น
              _buildStatColumn(assignedCount.toString(), 'Assigned'),
            ],
          ),
        ),

        // 2. ปุ่มเปิด/ปิด รับงาน
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Accepting submissions',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
              Switch(
                value: _isAccepting, // ผูกกับตัวแปร State
                activeColor: Colors.blueAccent,
                onChanged: (val) async {
                  // 1. เปลี่ยน UI ทันทีเพื่อให้ดูสมูท ไม่ต้องรอ API (Optimistic Update)
                  setState(() {
                    _isAccepting = val;
                  });

                  try {
                    // 2. ยิง API ไปหลังบ้าน
                    await ClassworkSimpleService.toggleSubmissionStatus(
                      widget.assignmentId, 
                      val,
                    );
                    // ถ้าสำเร็จก็ปล่อยผ่านไปเลย UI เปลี่ยนไปรอแล้ว
                  } catch (e) {
                    // 3. ถ้า API พัง ให้เด้งสวิตช์กลับไปค่าเดิม (สำคัญมาก!)
                    if (mounted) {
                      setState(() {
                        _isAccepting = !val; 
                      });
                      
                      // โชว์แจ้งเตือน Error
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(child: Text('อัปเดตสถานะไม่สำเร็จ: ${e.toString().replaceAll('Exception: ', '')}')),
                            ],
                          ),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 3. รายชื่อนักเรียน (กดแล้วไปหน้า GradingScreen)
        Expanded(
          child: _isLoadingSubmissions
              ? const Center(child: CircularProgressIndicator())
              : _submissions.isEmpty
              ? Center(
                  child: Text(
                    'ยังไม่มีการส่งงาน',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                )
              : ListView.separated(
                  itemCount: _submissions.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 64),
                  itemBuilder: (context, index) {
                    final submission = _submissions[index];
                    final bool hasScore = submission.score != null;
                    final statusLabel = submission.graded
                        ? 'Graded'
                        : 'Turned in';
                    final statusColor = submission.graded
                        ? Colors.orange
                        : Colors.green;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          submission.studentId.isNotEmpty
                              ? submission.studentId[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.blueAccent),
                        ),
                      ),
                      title: Text(
                        submission.studentId,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        hasScore
                            ? 'Score: ${submission.score}'
                            : submission.submittedAt != null
                            ? 'Submitted ${DateFormat('dd MMM HH:mm').format(submission.submittedAt!)}'
                            : 'ยังไม่มีข้อมูลการส่งงาน',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GradingScreen(
                              assignmentId: widget.assignmentId,
                              title: widget.title,
                              classId: widget.classId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Helper Widget สำหรับวาดตัวเลขสรุป
  Widget _buildStatColumn(String number, String label) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      ],
    );
  }
}
