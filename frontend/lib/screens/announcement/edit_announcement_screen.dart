import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/announcement_service.dart';

class EditAnnouncementScreen extends StatefulWidget {
  final String announcementId;
  final String title;
  final String? body;

  const EditAnnouncementScreen({
    super.key,
    required this.announcementId,
    required this.title,
    this.body,
  });

  @override
  State<EditAnnouncementScreen> createState() => _EditAnnouncementScreenState();
}

class _EditAnnouncementScreenState extends State<EditAnnouncementScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  bool _loading = false;
  bool _fetching = true;

  List<AnnouncementAttachmentDto> _existingAttachments = [];
  List<File> _newAttachments = [];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.title);
    _bodyCtrl = TextEditingController(text: widget.body ?? '');
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final dto = await AnnouncementService.getById(widget.announcementId);
      setState(() {
        _existingAttachments = dto.attachments;
        _fetching = false;
      });
    } catch (e) {
      print('Error fetching announcement details: $e');
      setState(() => _fetching = false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
        'xls',
        'xlsx',
        'txt',
        'png',
        'jpg',
        'jpeg',
      ],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _newAttachments.addAll(
          result.paths.where((p) => p != null).map((p) => File(p!)),
        );
      });
    }
  }

  Future<void> _deleteExistingAttachment(String attachmentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบไฟล์'),
        content: const Text('คุณต้องการลบไฟล์แนบนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await AnnouncementService.deleteAttachment(attachmentId);
        setState(() {
          _existingAttachments.removeWhere((a) => a.attachmentId == attachmentId);
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ลบไฟล์ไม่สำเร็จ: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาระบุหัวข้อ')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // 1. อัปเดตข้อมูลพื้นฐาน
      await AnnouncementService.update(
        announcementId: widget.announcementId,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
      );

      // 2. อัปโหลดไฟล์ใหม่ (ถ้ามี)
      for (var file in _newAttachments) {
        await AnnouncementService.uploadAttachment(widget.announcementId, file);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขประกาศ')),
      body: _fetching
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'หัวข้อ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bodyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'เนื้อหา',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 24),

                  // ส่วนของไฟล์แนบที่มีอยู่แล้ว
                  if (_existingAttachments.isNotEmpty) ...[
                    const Text(
                      'ไฟล์แนบเดิม',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._existingAttachments.map((att) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.description, color: Colors.blue),
                            title: Text(att.fileName, style: const TextStyle(fontSize: 14)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteExistingAttachment(att.attachmentId),
                            ),
                          ),
                        )),
                    const SizedBox(height: 16),
                  ],

                  // ส่วนของไฟล์ที่จะแนบเพิ่ม
                  const Text(
                    'แนบไฟล์เพิ่ม',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.add_link),
                    label: const Text('เลือกไฟล์เพิ่ม'),
                  ),
                  if (_newAttachments.isNotEmpty)
                    ..._newAttachments.asMap().entries.map((entry) => Card(
                          margin: const EdgeInsets.only(top: 8),
                          child: ListTile(
                            leading: const Icon(Icons.attach_file),
                            title: Text(
                              entry.value.path.split(Platform.pathSeparator).last,
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _newAttachments.removeAt(entry.key);
                                });
                              },
                            ),
                          ),
                        )),

                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('บันทึกการแก้ไข', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }
}
