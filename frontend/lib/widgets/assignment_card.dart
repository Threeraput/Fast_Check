// lib/widgets/assignment_card.dart (เฉพาะส่วนสำคัญ)

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/classwork_simple_service.dart';

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
    final bool isAcceptingSubmissions =
        extra['is_accepting_submissions'] is bool
        ? extra['is_accepting_submissions'] as bool
        : true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // 👈 3. ย้ายคำสั่งเปลี่ยนหน้ามาไว้ตรงนี้ (กดตรงไหนของ Card ก็ทำงาน)
          // 🚨 วางกับดักจุดที่ 3: เช็คค่าสุดท้ายก่อนส่งไปหน้า Detail
          print('🚀 DEBUG NAVIGATING: Sending isAccepting = ${isAcceptingSubmissions}');
          Navigator.pushNamed(
            context,
            '/assignment-detail',
            arguments: {
              'assignmentId': assignmentId,
              'title': title,
              'classId': classId,
              'isTeacher': isTeacher,
            },
          ).then((_) => onChanged?.call());
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.lightBlue[300],
                    child: Icon(
                      Icons.assignment_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'งาน: $title',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    df.format(postedAt.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),

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

              const SizedBox(height: 10),

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
        ),
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

  Future<void> _pickAndSubmit() async {
    try {
      setState(() => _busy = true);

      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (picked == null || picked.files.isEmpty) return;
      final path = picked.files.single.path;
      if (path == null) return;

      await ClassworkSimpleService.submitPdf(
        assignmentId: widget.assignmentId,
        pdfFile: File(path),
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
      await _pickAndSubmit();
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
            isAccepting ? Icons.picture_as_pdf_outlined : Icons.lock_outline,
          ),
          label: Text(
            isAccepting ? 'ส่ง PDF' : 'ปิดรับการส่งงาน',
            style: const TextStyle(color: Colors.white),
          ),
          onPressed: isAccepting ? _pickAndSubmit : null,
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
