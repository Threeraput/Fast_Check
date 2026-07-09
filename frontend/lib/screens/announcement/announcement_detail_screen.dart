import 'package:flutter/material.dart';
import 'package:frontend/utils/app_theme.dart';
import 'package:frontend/services/user_service.dart';
import 'package:intl/intl.dart';
import 'package:frontend/models/comment_model.dart';
import 'package:frontend/services/announcement_service.dart';
import 'package:frontend/services/classwork_simple_service.dart'; // 👈 เพิ่มตัวนี้
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/config.dart';
import 'package:frontend/widgets/glass_card.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final String announcementId;
  final String title;
  final String? body;
  final DateTime? postedAt;
  final bool pinned;
  final List? attachments; // 👈 เพิ่มตัวนี้

  const AnnouncementDetailScreen({
    super.key,
    required this.announcementId,
    required this.title,
    this.body,
    this.postedAt,
    this.pinned = false,
    this.attachments, // 👈 เพิ่มตัวนี้
  });

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  List<AnnouncementComment> _comments = [];
  bool _isLoadingComments = true;
  final TextEditingController _commentController = TextEditingController();
  List<AnnouncementAttachmentDto> _attachmentDtos = [];

  @override
  void initState() {
    super.initState();
    _fetchComments();
    _initAttachments();
  }

  void _initAttachments() {
    if (widget.attachments != null) {
      setState(() {
        _attachmentDtos = widget.attachments!
            .map((e) => AnnouncementAttachmentDto.fromJson(e))
            .toList();
      });
    }
  }

  Future<void> _fetchComments() async {
    try {
      // เรียกใช้ Service ของ Announcement ที่เราเพิ่งสร้าง
      final comments = await AnnouncementService.getComments(
        widget.announcementId,
      );
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

  Future<void> _openAttachment(AnnouncementAttachmentDto att) async {
    try {
      // ใช้ฟังก์ชันเดียวกับระบบงาน (Classwork) เพื่อความสม่ำเสมอ
      await ClassworkSimpleService.openAttachmentFile(
        storagePath: att.storagePath,
        preferredName: att.fileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ไม่สามารถเปิดไฟล์ได้: $e')));
      }
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    FocusScope.of(context).unfocus(); // ซ่อนคีย์บอร์ดตอนส่งเสร็จ

    try {
      final created = await AnnouncementService.addComment(
        announcementId: widget.announcementId,
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

  BoxDecoration _panelBox({double radius = 14}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.46),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy, HH:mm');
    final headerIcon = widget.pinned ? Icons.push_pin : Icons.campaign_outlined;
    final headerIconColor = widget.pinned
        ? Colors.red.shade700
        : Colors.blue.shade700;
    final displayTitle = widget.pinned
        ? '[ปักหมุด] ${widget.title}'
        : widget.title;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD6E4FF)),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        title: const Text('รายละเอียดประกาศ', style: TextStyle(fontWeight: FontWeight.w800)),
        // หน้าประกาศไม่มีการให้คะแนน เลยไม่ต้องมีปุ่มตรวจงาน
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: GlassCard(
          accent: widget.pinned ? Colors.red.shade600 : Colors.blue.shade600,
          radius: 18,
          padding: EdgeInsets.zero,
          child: Column(
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
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _panelBox(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: headerIconColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  headerIcon,
                                  color: headerIconColor,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayTitle,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.postedAt != null
                                          ? 'ประกาศเมื่อ: ${df.format(widget.postedAt!)}'
                                          : 'ประกาศ',
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
                          // เนื้อหาประกาศ
                          Text(
                            widget.body?.isNotEmpty == true
                                ? widget.body!
                                : '(ไม่มีเนื้อหาเพิ่มเติม)',
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                          const SizedBox(height: 20),

                          // 🔹 ส่วนของไฟล์แนบ (ถ้ามี)
                          if (_attachmentDtos.isNotEmpty) ...[
                            const Divider(),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'ไฟล์แนบ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            ..._attachmentDtos.map(
                              (att) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  decoration: _panelBox(radius: 12),
                                  child: ListTile(
                                    leading: Icon(
                                      att.mimeType.contains('image')
                                          ? Icons.image_outlined
                                          : Icons.description_outlined,
                                      color: AppColors.primary,
                                    ),
                                    title: Text(
                                      att.fileName,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      '${(att.sizeBytes / 1024).toStringAsFixed(1)} KB',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: const Icon(
                                      Icons.open_in_new,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                                    onTap: () => _openAttachment(att),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),
                          const Divider(),
                          // หัวข้อบอกจำนวนคอมเมนต์
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'ความคิดเห็นในชั้นเรียน (${_comments.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ],
                        ),
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

                  // 🚨 1. ดึง URL ของรูปภาพ (คุณอาจจะต้องปรับบรรทัดนี้ให้ตรงกับ Data Model ของคุณ)
                  // ถ้าระบบคอมเมนต์มีส่ง avatarUrl มาด้วย:
                  final String? avatarUrl = comment.avatarUrl;

                  // หรือถ้าต้องไปหาในสมุดหน้าเหลือง:
                  // final String? avatarUrl = _userIndex[comment.userId]?.avatarUrl;

                  // 🚨 2. แปลงเป็น URL แบบเต็ม (ถ้าต้องใช้)
                  final String? fullAvatarUrl = avatarUrl != null
                      ? UserService.absoluteAvatarUrl(avatarUrl)
                      : null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Container(
                      decoration: _panelBox(radius: 12),
                      padding: const EdgeInsets.all(10),
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🚨 3. วาด Avatar โดยเช็คว่ามี URL ไหม
                        fullAvatarUrl != null && fullAvatarUrl.isNotEmpty
                            ? CircleAvatar(
                                radius: 20,
                                backgroundImage: NetworkImage(
                                  fullAvatarUrl,
                                ), // โชว์รูป!
                              )
                            : CircleAvatar(
                                radius: 20,
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
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. ส่วนที่เกาะอยู่ล่างสุด: ช่องพิมพ์คอมเมนต์
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: _panelBox(radius: 12),
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
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.55),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
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
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(42, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: _sendComment,
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}
