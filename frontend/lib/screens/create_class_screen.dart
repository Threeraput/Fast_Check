import 'package:flutter/material.dart';
import 'package:frontend/models/classroom.dart';
import 'package:frontend/services/class_service.dart';

class CreateClassScreen extends StatefulWidget {
  final Classroom? editing;
  const CreateClassScreen({super.key, this.editing});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  DateTime? _startAt;
  DateTime? _endAt;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _nameCtl.text = e.name ?? '';
      _descCtl.text = e.description ?? '';
      if ((e.startTime ?? '').isNotEmpty) {
        _startAt = DateTime.tryParse(e.startTime!);
      }
      if ((e.endTime ?? '').isNotEmpty) _endAt = DateTime.tryParse(e.endTime!);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final init = (isStart ? _startAt : _endAt) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: init,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueAccent,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (d == null) return;
    setState(() {
      if (isStart) {
        _startAt = d;
      } else {
        _endAt = d;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (widget.editing == null) {
        final body = ClassroomCreate(
          name: _nameCtl.text.trim(),
          description: _descCtl.text.trim().isEmpty
              ? null
              : _descCtl.text.trim(),
          startTime: _startAt?.toIso8601String(),
          endTime: _endAt?.toIso8601String(),
        );
        await ClassService.createClassroom(body);
      } else {
        final body = ClassroomUpdate(
          name: _nameCtl.text.trim(),
          description: _descCtl.text.trim().isEmpty
              ? null
              : _descCtl.text.trim(),
          startTime: _startAt?.toIso8601String(),
          endTime: _endAt?.toIso8601String(),
        );
        await ClassService.updateClassroom(widget.editing!.classId!, body);
      }
      if (mounted) Navigator.of(context).pop(true);
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
  final editing = widget.editing != null;
  return Scaffold(
    backgroundColor: Colors.grey[100], // พื้นหลังอ่อนๆ เพื่อให้กล่องขาวเด่นขึ้น
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(editing ? 'แก้ไขคลาส' : 'สร้างคลาส') 
      ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: AbsorbPointer(
        absorbing: _loading,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white, // กล่องสีขาว
              borderRadius: BorderRadius.circular(16), // มุมโค้งมน
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08), // เงาอ่อนๆ
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameCtl,
                    decoration: InputDecoration(
                      labelText: 'ชื่อคลาส',
                      labelStyle: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      hintText: 'กรอกชื่อคลาสของคุณ เช่น คณิตศาสตร์ ม.4/1',
                      hintStyle: const TextStyle(
                          color: Colors.black45, fontSize: 14),
                      prefixIcon: const Icon(Icons.class_,
                          color: Colors.blueAccent),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.shade300, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Colors.blueAccent, width: 1.5),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'กรอกชื่อคลาส' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtl,
                    decoration: InputDecoration(
                      labelText: 'คำอธิบาย (ไม่บังคับ)',
                      labelStyle: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      hintText: 'กรอกคำอธิบายคลาสของคุณ',
                      hintStyle: const TextStyle(
                          color: Colors.black45, fontSize: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.shade300, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Colors.blueAccent, width: 1.5),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today,
                              color: Colors.black38),
                          label: Text(
                            _startAt == null
                                ? 'วันเริ่ม'
                                : _startAt!.toIso8601String().split('T').first,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              ),
                          ),
                          onPressed: () => _pickDate(true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event, color: Colors.black38),
                          label: Text(
                            _endAt == null
                                ? 'วันสิ้นสุด'
                                : _endAt!.toIso8601String().split('T').first,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              ),
                          ),
                          onPressed: () => _pickDate(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      editing ? 'บันทึกการแก้ไข' : 'สร้างห้องเรียน',
                      style: const TextStyle(fontSize: 16),
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
