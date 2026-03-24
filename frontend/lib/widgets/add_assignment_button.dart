// lib/widgets/add_assignment_button.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/classwork_simple_service.dart';

class AddAssignmentButton extends StatefulWidget {
  final String classId;
  final VoidCallback? onCreated; // ให้หน้าแม่รีเฟรชหลังสร้างเสร็จ
  final bool
  iconOnly; // true = แสดงเป็นไอคอนใน AppBar, false = เป็น FAB/ปุ่มเต็ม

  const AddAssignmentButton({
    super.key,
    required this.classId,
    this.onCreated,
    this.iconOnly = true,
  });

  @override
  State<AddAssignmentButton> createState() => _AddAssignmentButtonState();
}

class _AddAssignmentButtonState extends State<AddAssignmentButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (widget.iconOnly) {
      return IconButton(
        tooltip: 'เพิ่มงาน',
        icon: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.assignment_ind_outlined),
        onPressed: _busy ? null : _openCreateDialog,
      );
    }

    return FloatingActionButton.extended(
      onPressed: _busy ? null : _openCreateDialog,
      icon: const Icon(Icons.assignment_ind_outlined),
      label: _busy ? const Text('กำลังสร้าง...') : const Text('เพิ่มงาน'),
    );
    // ถ้าต้องการเป็นปุ่มธรรมดา:
    // return FilledButton.icon( ... );
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateAssignmentDialog(classId: widget.classId),
    );
    if (created == true) {
      widget.onCreated?.call();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('สร้างงานสำเร็จ')));
      }
    }
  }
}

class _CreateAssignmentDialog extends StatefulWidget {
  final String classId;
  const _CreateAssignmentDialog({required this.classId});

  @override
  State<_CreateAssignmentDialog> createState() =>
      _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState extends State<_CreateAssignmentDialog> {
  final _title = TextEditingController();
  final _maxScore = TextEditingController(text: '100');
  DateTime? _dueDate;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _maxScore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy • HH:mm');
    return AlertDialog(
      title: const Text('สร้างงานใหม่'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'ชื่อเรื่อง',
              hintText: 'เช่น Homework 1',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _maxScore,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'คะแนนเต็ม'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _dueDate == null
                      ? 'กรุณาเลือกกำหนดส่ง'
                      : 'กำหนดส่ง: ${df.format(_dueDate!.toLocal())}',
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: const Text('เลือกวัน/เวลา'),
                onPressed: _pickDateTime,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('สร้างงาน'),
        ),
      ],
    );
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 0)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      initialDate: now,
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;

    setState(() {
      _dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final maxScore = int.tryParse(_maxScore.text.trim());
    final due = _dueDate;

    if (title.isEmpty) {
      _warn('กรุณากรอกชื่อเรื่อง');
      return;
    }
    if (maxScore == null || maxScore <= 0) {
      _warn('คะแนนเต็มไม่ถูกต้อง');
      return;
    }
    if (due == null) {
      _warn('กรุณาเลือกกำหนดส่ง');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ClassworkSimpleService.createAssignmentTyped(
        classId: widget.classId,
        title: title,
        maxScore: maxScore,
        dueDate: due,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _submitting = false);
      _warn('สร้างงานไม่สำเร็จ: $e');
    }
  }

  void _warn(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
