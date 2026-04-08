import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/models/comment_model.dart';
import 'package:frontend/services/announcement_service.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final String announcementId;
  final String title;
  final String? body;
  final DateTime? postedAt;

  const AnnouncementDetailScreen({
    super.key,
    required this.announcementId,
    required this.title,
    this.body,
    this.postedAt,
  });

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  List<AnnouncementComment> _comments = [];
  bool _isLoadingComments = true;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      // เรียกใช้ Service ของ Announcement ที่เราเพิ่งสร้าง
      final comments = await AnnouncementService.getComments(widget.announcementId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingComments = false);
      print("Error fetching announcement comments: $e");
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    FocusScope.of(context).unfocus(); // ซ่อนคีย์บอร์ดตอนส่งเสร็จ
    
    try {
      await AnnouncementService.addComment(
        announcementId: widget.announcementId,
        content: text,
      );
      _fetchComments(); // รีเฟรชคอมเมนต์ใหม่
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
    final df = DateFormat('dd MMM yyyy, HH:mm');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('รายละเอียดประกาศ'),
        // 💡 หน้าประกาศไม่มีการให้คะแนน เลยไม่ต้องมีปุ่มตรวจงานครับ! คลีนๆ เลย
      ),
      body: Column(
        children: [
          // 1. พื้นที่เลื่อนได้ (รวมรายละเอียดประกาศ + คอมเมนต์)
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchComments,
              child: ListView.builder(
                // จำนวน item = 1 (ตัวประกาศ) + จำนวนคอมเมนต์
                itemCount: 1 + _comments.length,
                itemBuilder: (context, index) {
                  
                  // ====== ส่วนที่ 1: รายละเอียดประกาศ (อยู่บนสุดเสมอ) ======
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
                                  color: Colors.orange.withOpacity(0.1), // เปลี่ยนธีมสีนิดหน่อยให้ต่างจากงาน
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.campaign, color: Colors.orange, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.postedAt != null 
                                          ? 'ประกาศเมื่อ: ${df.format(widget.postedAt!)}' 
                                          : 'ประกาศ',
                                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // เนื้อหาประกาศ
                          Text(
                            widget.body?.isNotEmpty == true ? widget.body! : '(ไม่มีเนื้อหาเพิ่มเติม)',
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                          const SizedBox(height: 24),
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

                  // ลบ 1 ออกจาก index เพราะ 0 เป็นประกาศไปแล้ว
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
                      maxLines: 4,
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