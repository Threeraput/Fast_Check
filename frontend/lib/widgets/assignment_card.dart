// lib/widgets/assignment_card.dart (เฉพาะส่วนสำคัญ)

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/classwork_simple_service.dart';
import 'package:frontend/utils/app_theme.dart';
import 'package:frontend/widgets/glass_card.dart';

class AssignmentCard extends StatelessWidget {
  final String classId;
  final Map<String, dynamic> extra;
  final DateTime postedAt;
  final bool isTeacher;
  final VoidCallback? onChanged;

  const AssignmentCard({
    super.key,
    required this.classId,
    required this.extra,
    required this.postedAt,
    required this.isTeacher,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy • HH:mm');

    final assignmentId = extra['assignment_id']?.toString() ?? '';
    final title = extra['title']?.toString() ?? 'Assignment';
    final dueIso = extra['due_date']?.toString();
    final due = DateTime.tryParse(dueIso ?? '');
    final maxScore = extra['max_score'];

    // ฝั่งนักเรียน: มีสถานะของฉันติดมาด้วย
    final Map<String, dynamic>? my =
        (extra['my_submission'] is Map<String, dynamic>)
        ? (extra['my_submission'] as Map<String, dynamic>)
        : null;

    final bool alreadySubmitted =
        my != null ||
        (extra['computed_status']?.toString() ?? '') != 'Not_Submitted';
    final dynamic rawScore = my?['score'];
    final int? myScore = rawScore is num
        ? rawScore.toInt()
        : int.tryParse(rawScore?.toString() ?? '');
    final bool isAcceptingSubmissions =
        extra['is_accepting_submissions'] is bool
        ? extra['is_accepting_submissions'] as bool
        : true;

    return GlassCard(
      accent: AppColors.primary,
      radius: 16,
      padding: const EdgeInsets.all(10),
      onTap: () {
        print(
          '🚀 DEBUG NAVIGATING: Sending isAccepting = ${isAcceptingSubmissions}',
        );
        Navigator.pushNamed(
          context,
          '/assignment-detail',
          arguments: {
            'assignmentId': assignmentId,
            'title': title,
            'classId': classId,
            'isTeacher': isTeacher,
            'dueDateIso': dueIso,
            'maxScore': maxScore,
          },
        ).then((_) => onChanged?.call());
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'งาน: $title',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Text(
                    df.format(postedAt.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),

              if (due != null)
                Text(
                  'กำหนดส่ง: ${df.format(due.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (maxScore != null)
                Text(
                  'คะแนนเต็ม: $maxScore',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (!isTeacher && alreadySubmitted)
                Text(
                  myScore != null
                      ? 'คะแนนที่ได้: $myScore'
                      : 'คะแนนที่ได้: ยังไม่ได้ตรวจ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),

              const SizedBox(height: 9),

              if (!isTeacher)
                Align(
                  alignment: Alignment.centerRight,
                  child: _StudentSubmitButton(
                    assignmentId: assignmentId,
                    alreadySubmitted: alreadySubmitted,
                    isAcceptingSubmissions: isAcceptingSubmissions,
                    onChanged: onChanged,
                  ),
                ),
              // else
              //   Align(
              //     alignment: Alignment.centerLeft,
              //     child: OutlinedButton.icon(
              //       style: OutlinedButton.styleFrom(
              //         backgroundColor: Colors.lightBlue[300],
              //         side: BorderSide.none
              //       ),
              //       label: const Text(
              //         style: TextStyle(color: Colors.white),
              //         'ดูการส่งของนักเรียน',
              //       ),
              //       onPressed: () {
              //         // ไปหน้า detail ของอาจารย์
              //         Navigator.pushNamed(
              //           context,
              //           '/assignment-detail',
              //           arguments: {
              //             'assignmentId': assignmentId,
              //             'title': title,
              //             'classId': classId, // ✅ ใส่ตรงนี้
              //           },
              //         ).then((_) => onChanged?.call());
              //       },
              //     ),
              //   ),
        ],
      ),
    );
  }
}

class _StudentSubmitButton extends StatefulWidget {
  final String assignmentId;
  final bool alreadySubmitted;
  final bool isAcceptingSubmissions;
  final VoidCallback? onChanged;

  const _StudentSubmitButton({
    required this.assignmentId,
    required this.alreadySubmitted,
    required this.isAcceptingSubmissions,
    this.onChanged,
  });

  @override
  State<_StudentSubmitButton> createState() => _StudentSubmitButtonState();
}

class _StudentSubmitButtonState extends State<_StudentSubmitButton> {
  bool _busy = false;

  Future<void> _showSubmitDialog() async {
    final textController = TextEditingController();
    String? selectedPdfPath;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final selectedName = selectedPdfPath == null
                ? 'ไม่ได้แนบไฟล์'
                : selectedPdfPath!.split(RegExp(r'[\\/]')).last;

            return AlertDialog(
              title: const Text('ส่งงาน'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'พิมพ์คำตอบได้เลย หรือแนบ PDF เพิ่มก็ได้',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'คำตอบ',
                        hintText: 'เช่น 2+2 = 4',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf'],
                            );
                            if (picked == null || picked.files.isEmpty) return;
                            final path = picked.files.single.path;
                            if (path == null || path.trim().isEmpty) return;
                            setDialogState(() => selectedPdfPath = path);
                          },
                          icon: const Icon(Icons.attach_file),
                          label: const Text('แนบ PDF'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () async {
                    final answer = textController.text.trim();
                    if (answer.isEmpty && selectedPdfPath == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('กรุณาพิมพ์คำตอบหรือแนบ PDF อย่างน้อย 1 อย่าง'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('ส่งงาน'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true) {
      textController.dispose();
      return;
    }

    try {
      setState(() => _busy = true);

      final answer = textController.text.trim();
      final file = selectedPdfPath == null ? null : File(selectedPdfPath!);
      await ClassworkSimpleService.submitAssignment(
        assignmentId: widget.assignmentId,
        pdfFile: file,
        submissionText: answer.isEmpty ? null : answer,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ส่งงานเรียบร้อย')));
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ส่งงานไม่สำเร็จ: $e')));
    } finally {
      textController.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmResubmit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการส่งใหม่'),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'คุณได้ส่งงานแล้ว ต้องการส่งไฟล์ใหม่'),
              TextSpan(
                text: ' ทับของเดิมหรือไม่?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent, // 🔴 เน้นสีแดงให้เตือนชัด ๆ
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(style: TextStyle(color: Colors.grey), 'ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ส่งใหม่'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _showSubmitDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox(
        height: 40,
        width: 140,
        child: Center(child: CircularProgressIndicator(color: Colors.blue)),
      );
    }

    final bool isAccepting = widget.isAcceptingSubmissions;

    if (!widget.alreadySubmitted) {
      // ยังไม่ส่ง → ปุ่มสีหลัก
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: isAccepting
                ? Colors.lightBlue[300]
                : Colors.grey[400],
          ),
          icon: Icon(
            isAccepting ? Icons.upload_file_outlined : Icons.lock_outline,
          ),
          label: Text(
            isAccepting ? 'ส่งงาน' : 'ปิดรับการส่งงาน',
            style: const TextStyle(color: Colors.white),
          ),
          onPressed: isAccepting ? _showSubmitDialog : null,
        ),
      );
    } else {
      // ส่งแล้ว → ปุ่มสีเทา แสดงว่า "ส่งแล้ว" แต่ยังกดได้ (จะขึ้นยืนยันก่อนส่งใหม่)
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.check_circle),
          label: const Text('ส่งแล้ว'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).disabledColor,
            side: BorderSide(color: Theme.of(context).disabledColor),
          ),
          onPressed: _confirmResubmit,
        ),
      );
    }
  }
}
