import 'package:flutter/material.dart';
import '../services/announcement_service.dart';

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

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.title);
    _bodyCtrl = TextEditingController(text: widget.body ?? '');
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await AnnouncementService.update(
        announcementId: widget.announcementId,
        title: _titleCtrl.text,
        body: _bodyCtrl.text,
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('อัปเดตไม่สำเร็จ: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขประกาศ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'หัวข้อ'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              decoration: const InputDecoration(labelText: 'เนื้อหา'),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('บันทึกการแก้ไข'),
            ),
          ],
        ),
      ),
    );
  }
}
