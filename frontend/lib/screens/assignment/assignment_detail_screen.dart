import 'package:flutter/material.dart';
import 'package:frontend/models/comment_model.dart'; 
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

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  List<AssignmentComment> _comments = [];
  bool _isLoadingComments = true;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final comments = await ClassworkSimpleService.getComments(widget.assignmentId);
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

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    FocusScope.of(context).unfocus(); // ซ่อนคีย์บอร์ดตอนส่งเสร็จ
    
    try {
      await ClassworkSimpleService.addComment(
        assignmentId: widget.assignmentId,
        content: text,
      );
      _fetchComments(); 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งคอมเมนต์ไม่สำเร็จ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ให้พื้นหลังเป็นสีขาวดูคลีนๆ
      appBar: AppBar(
        title: const Text('รายละเอียดงาน'),
        actions: [
          // 👈 3. ใส่ if ครอบไว้ แปลว่า "ถ้าเป็นครู ค่อยโชว์ปุ่มนี้!"
          if (widget.isTeacher) 
            IconButton(
              icon: const Icon(Icons.assignment_ind_outlined),
              tooltip: 'ตรวจงานนักเรียน',
              onPressed: () {
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
            )
        ],
      ),
      body: Column(
        children: [
          // 1. พื้นที่เลื่อนได้ (รวมรายละเอียดงาน + คอมเมนต์)
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchComments,
              child: ListView.builder(
                // จำนวนของ = (หัวข้องาน 1 ชิ้น) + (จำนวนคอมเมนต์ทั้งหมด)
                itemCount: 1 + _comments.length,
                itemBuilder: (context, index) {
                  
                  // ====== ส่วนที่ 1: รายละเอียดงาน (อยู่บนสุดเสมอ) ======
                  if (index == 0) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
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
                                child: const Icon(Icons.assignment, color: Colors.blueAccent, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ครบกำหนด: ไม่ระบุ', // TODO: ดึงข้อมูล Due Date มาใส่ตรงนี้
                                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          const Divider(),
                          // หัวข้อบอกจำนวนคอมเมนต์
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'ความคิดเห็นในชั้นเรียน (${_comments.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // ====== ส่วนที่ 2: คอมเมนต์ต่อท้าย ======
                  if (_isLoadingComments && index == 1) {
                    return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  // ลบ 1 ออกจาก index เพราะ index 0 เป็นของรายละเอียดงานไปแล้ว
                  final comment = _comments[index - 1]; 
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          child: Text(
                            comment.commenterName.isNotEmpty ? comment.commenterName[0].toUpperCase() : '?',
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('dd MMM HH:mm').format(comment.createdAt),
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

          // 2. ส่วนที่เกาะอยู่ล่างสุด: ช่องพิมพ์คอมเมนต์
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 5,
                )
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 1,
                      maxLines: 4, // ให้ช่องพิมพ์ขยายได้ถ้าพิมพ์ยาวๆ
                      decoration: InputDecoration(
                        hintText: "เพิ่มความคิดเห็นในชั้นเรียน...",
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendComment,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}