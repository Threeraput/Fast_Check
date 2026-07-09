import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/services/announcement_service.dart';
import 'package:frontend/utils/app_theme.dart';
import 'package:frontend/widgets/glass_card.dart';
import 'package:intl/intl.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  final String classId;
  final String className;

  const CreateAnnouncementScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _titleCtl = TextEditingController();
  final _bodyCtl = TextEditingController();
  final List<File> _attachments = [];

  bool _posting = false;
  bool _pinned = false;
  DateTime? _expiresAt;

  @override
  void dispose() {
    _titleCtl.dispose();
    _bodyCtl.dispose();
    super.dispose();
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

    if (!mounted || result == null) return;
    setState(() {
      _attachments.addAll(
        result.paths.whereType<String>().map((path) => File(path)),
      );
    });
  }

  void _removeAttachment(int index) {
    if (index < 0 || index >= _attachments.length) return;
    setState(() => _attachments.removeAt(index));
  }

  Future<void> _pickExpireDateTime() async {
    final now = DateTime.now();
    final initial = _expiresAt ?? now.add(const Duration(days: 7));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || time == null) return;

    setState(() {
      _expiresAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _post() async {
    final title = _titleCtl.text.trim();
    final body = _bodyCtl.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _posting = true);
    try {
      final created = await AnnouncementService.create(
        classId: widget.classId,
        title: title,
        body: body.isEmpty ? null : body,
        pinned: _pinned,
        visible: true,
        expiresAt: _expiresAt,
      );

      for (final file in _attachments) {
        await AnnouncementService.uploadAttachment(created.announcementId, file);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create announcement: $e')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy HH:mm');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Create Announcement - ${widget.className}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: GlassCard(
                accent: AppColors.primary,
                radius: 18,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassCard(
                      accent: const Color(0xFF2563EB),
                      radius: 14,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'CREATE ANNOUNCEMENT',
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _titleCtl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.article_outlined),
                        labelText: 'Title',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bodyCtl,
                      minLines: 4,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: 'Details',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Attachments',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (_attachments.isNotEmpty)
                      ..._attachments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final file = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.attach_file,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              file.path.split('\\').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => _removeAttachment(index),
                            ),
                          ),
                        );
                      }),
                    OutlinedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Attach Files'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _pinned,
                      onChanged: (v) => setState(() => _pinned = v ?? false),
                      title: const Text(
                        'Pin this announcement',
                        style: TextStyle(fontSize: 13),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 6),
                    GlassCard(
                      accent: const Color(0xFF0EA5A4),
                      radius: 12,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expire Time (optional)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _expiresAt == null
                                ? 'No expiration set'
                                : df.format(_expiresAt!.toLocal()),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickExpireDateTime,
                                icon: const Icon(Icons.event, size: 16),
                                label: const Text('Set Time'),
                              ),
                              if (_expiresAt != null)
                                TextButton.icon(
                                  onPressed: () => setState(() => _expiresAt = null),
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: const Text('Clear'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _posting ? null : _post,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        _posting ? 'Posting...' : 'Post Announcement',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                    if (_posting)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Posting...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
