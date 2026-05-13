import 'package:flutter/material.dart';
import 'package:frontend/models/classroom.dart';
import 'package:frontend/models/classwork.dart';
import 'package:frontend/models/comment_model.dart';
import 'package:frontend/services/class_service.dart';
import 'package:frontend/services/classwork_simple_service.dart';
import 'package:frontend/services/user_service.dart';
import 'package:intl/intl.dart';
import 'package:frontend/screens/assignment/grading_screen.dart';

class AssignmentDetailScreen extends StatefulWidget {
  final String assignmentId;
  final String title;
  final String? classId;
  final bool isTeacher;
  final DateTime? dueDate;
  final int? maxScore;

  const AssignmentDetailScreen({
    super.key,
    required this.assignmentId,
    required this.title,
    this.classId,
    this.isTeacher = false,
    this.dueDate,
    this.maxScore,
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
  ClassworkSubmission? _mySubmission;
  bool _isLoadingMySubmission = false;
  bool _busyMySubmissionAction = false;
  List<AssignmentAttachment> _attachments = [];
  bool _isLoadingAttachments = true;
  bool _busyAttachmentAction = false;
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
    _fetchAttachments();
    _fetchMySubmission();

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

  Future<void> _fetchMySubmission() async {
    if (widget.isTeacher || widget.classId == null) return;

    setState(() {
      _isLoadingMySubmission = true;
    });

    try {
      final views = await ClassworkSimpleService.getStudentAssignmentsTyped(
        widget.classId!,
      );
      final matched = views.where((v) {
        return v.assignment.assignmentId == widget.assignmentId;
      }).toList();

      if (!mounted) return;
      setState(() {
        _mySubmission = matched.isNotEmpty ? matched.first.mySubmission : null;
        _isLoadingMySubmission = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mySubmission = null;
        _isLoadingMySubmission = false;
      });
      print('Error fetching my submission: $e');
    }
  }

  Future<void> _openMySubmissionFile() async {
    final filePath = _mySubmission?.contentUrl;
    if (filePath == null || filePath.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่พบไฟล์งานที่ส่ง')));
      return;
    }

    setState(() => _busyMySubmissionAction = true);
    try {
      await ClassworkSimpleService.openAttachmentFile(
        storagePath: filePath,
        preferredName: 'my_submission.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เปิดไฟล์ที่ส่งไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _busyMySubmissionAction = false);
    }
  }

  String _statusLabel(SubmissionLateness status) {
    switch (status) {
      case SubmissionLateness.onTime:
        return 'ตรงเวลา';
      case SubmissionLateness.late:
        return 'ส่งช้า';
      case SubmissionLateness.notSubmitted:
        return 'ยังไม่ส่ง';
    }
  }

  String _fileNameFromStoragePath(String? path) {
    if (path == null || path.trim().isEmpty) return '-';
    final clean = path.split('?').first.trim();
    if (clean.isEmpty) return '-';
    final name = clean.split('/').last;
    if (name.isEmpty) return '-';
    return Uri.decodeComponent(name);
  }

  Widget _buildMySubmissionSection() {
    if (widget.isTeacher) return const SizedBox.shrink();

    final my = _mySubmission;
    final submittedAt = my?.submittedAt;
    final submittedFileName = _fileNameFromStoragePath(my?.contentUrl);
    final submittedAtText = submittedAt != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(submittedAt)
        : '-';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'งานที่ฉันส่ง',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            if (_isLoadingMySubmission)
              const LinearProgressIndicator(minHeight: 3)
            else if (my == null)
              Text(
                'ยังไม่ได้ส่งงาน',
                style: TextStyle(color: Colors.grey.shade700),
              )
            else ...[
              Text('สถานะ: ${_statusLabel(my.submissionStatus)}'),
              Text('ไฟล์ที่ส่ง: $submittedFileName'),
              Text('เวลาส่ง: $submittedAtText'),
              if (my.score != null) Text('คะแนนที่ได้: ${my.score}'),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: _busyMySubmissionAction
                    ? null
                    : _openMySubmissionFile,
                icon: _busyMySubmissionAction
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new),
                label: Text(
                  _busyMySubmissionAction
                      ? 'กำลังเปิดไฟล์...'
                      : 'ดูไฟล์ที่ส่งแล้ว',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _fetchAttachments() async {
    try {
      final items = await ClassworkSimpleService.getAssignmentAttachments(
        widget.assignmentId,
      );
      if (!mounted) return;
      setState(() {
        _attachments = items;
        _isLoadingAttachments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _attachments = [];
        _isLoadingAttachments = false;
      });
    }
  }

  Future<void> _openAttachment(AssignmentAttachment item) async {
    try {
      await ClassworkSimpleService.openAttachmentFile(
        storagePath: item.storagePath,
        preferredName: item.fileName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เปิดไฟล์ไม่สำเร็จ: $e')));
    }
  }

  Future<void> _deleteAttachment(AssignmentAttachment item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบไฟล์แนบ'),
        content: Text('ต้องการลบไฟล์ ${item.fileName} ใช่หรือไม่'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    setState(() => _busyAttachmentAction = true);
    try {
      await ClassworkSimpleService.deleteAssignmentAttachment(
        item.attachmentId,
      );
      if (!mounted) return;
      setState(() {
        _attachments = _attachments
            .where((attachment) => attachment.attachmentId != item.attachmentId)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ลบไฟล์ไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _busyAttachmentAction = false);
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
      final created = await ClassworkSimpleService.addComment(
        assignmentId: widget.assignmentId,
        content: text,
      );
      if (!mounted) return;
      setState(() {
        _comments = [created, ..._comments];
      });
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
    final dueText = widget.dueDate != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(widget.dueDate!.toLocal())
        : 'ไม่ระบุ';
    final scoreText = widget.maxScore != null
        ? '${widget.maxScore} points'
        : 'ไม่ระบุคะแนน';

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _fetchComments();
              await _fetchAttachments();
              await _fetchMySubmission();
            },
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
                                    '$scoreText • ครบกำหนด: $dueText',
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
                          child: Row(
                            children: [
                              const Icon(
                                Icons.attach_file,
                                color: Colors.blueAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'เอกสารประกอบงาน',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isLoadingAttachments)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: LinearProgressIndicator(minHeight: 3),
                          )
                        else if (_attachments.isEmpty)
                          Text(
                            'ไม่มีไฟล์แนบ',
                            style: TextStyle(color: Colors.grey.shade600),
                          )
                        else
                          ..._attachments.map((item) {
                            final kb = (item.sizeBytes / 1024).toStringAsFixed(
                              1,
                            );
                            return Card(
                              margin: const EdgeInsets.only(top: 8),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.insert_drive_file_outlined,
                                  color: Colors.blueAccent,
                                ),
                                title: Text(
                                  item.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text('$kb KB'),
                                onTap: _busyAttachmentAction
                                    ? null
                                    : () => _openAttachment(item),
                                trailing: widget.isTeacher
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: _busyAttachmentAction
                                            ? null
                                            : () => _deleteAttachment(item),
                                      )
                                    : const Icon(Icons.open_in_new, size: 18),
                              ),
                            );
                          }),
                        _buildMySubmissionSection(),
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
                final String? fullAvatarUrl = UserService.absoluteAvatarUrl(
                  comment.avatarUrl,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      fullAvatarUrl != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(fullAvatarUrl),
                              radius: 20,
                            )
                          : CircleAvatar(
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
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'อัปเดตสถานะไม่สำเร็จ: ${e.toString().replaceAll('Exception: ', '')}',
                                ),
                              ),
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
                          submission.username.isNotEmpty
                              ? submission.username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.blueAccent),
                        ),
                      ),
                      title: Text(
                        '${submission.firstName} ${submission.lastName}',
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
