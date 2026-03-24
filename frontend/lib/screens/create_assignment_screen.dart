import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/classwork_simple_service.dart';

class CreateAssignmentScreen extends StatefulWidget {
  final String classId;

  const CreateAssignmentScreen({super.key, required this.classId});

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _maxScoreController = TextEditingController(text: '100');
  DateTime? _dueDate;

  bool _submitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกวันกำหนดส่ง')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await ClassworkSimpleService.createAssignment(
        classId: widget.classId,
        title: _titleController.text.trim(),
        maxScore: int.tryParse(_maxScoreController.text) ?? 100,
        dueDate: _dueDate!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('สร้างงานสำเร็จ')));
      Navigator.pop(context, true); // ✅ ส่ง true กลับไปรีเฟรชหน้าก่อนหน้า
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _pickDueDate() async {
  final now = DateTime.now();

  // 🔹 ส่วน Date Picker
  final picked = await showDatePicker(
    context: context,
    initialDate: now.add(const Duration(days: 1)),
    firstDate: now,
    lastDate: DateTime(now.year + 2),
    builder: (BuildContext context, Widget? child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Colors.blue, // 🔵 สีวงกลมวันที่เลือก
            onPrimary: Colors.white, // 🔵 สีตัวเลขในวงกลม
            surface: Colors.white, // พื้นหลัง popup
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue, // 🔵 สีปุ่ม Cancel / OK
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        child: child!,
      );
    },
  );

  if (picked == null) return;

  // 🔹 ส่วน Time Picker
  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 23, minute: 59),
    builder: (BuildContext context, Widget? child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.lightBlue, // 🔵 สีไฮไลต์วงกลมรอบตัวเลข
            secondary: Colors.lightBlueAccent, // 🔵 สีเวลาที่เลือก
            onPrimary: Colors.white, // สีตัวเลขในวงกลม
            surface: Colors.white,
            onSurface: Colors.black87, // สีข้อความทั่วไป
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue, // 🔵 สีปุ่ม Cancel / OK
            ),
          ),
        ),
        child: child!,
      );
    },
  );

  if (time == null) return;

  setState(() {
    _dueDate = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    );
  });
}


  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('สร้างงานใหม่')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 500,
            ), // ✅ จำกัดความกว้างให้อยู่กลางจอ
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20), // ✅ มุมโค้งมน
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text(
                    'สร้างงานใหม่',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // ✅ ช่องกรอกชื่องาน
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'ชื่องาน',
                      prefixIcon: const Icon(Icons.assignment_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'กรุณากรอกชื่องาน' : null,
                  ),

                  const SizedBox(height: 16),

                  // ✅ ช่องกรอกคะแนนเต็ม
                  TextFormField(
                    controller: _maxScoreController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'คะแนนเต็ม',
                      prefixIcon: const Icon(Icons.score_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ✅ วันที่กำหนดส่ง
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: const Text('กำหนดส่ง'),
                      subtitle: Text(
                        _dueDate == null
                            ? 'ยังไม่ได้เลือก'
                            : df.format(_dueDate!),
                        style: TextStyle(
                          color: _dueDate == null
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today_outlined),
                        onPressed: _pickDueDate,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ✅ ปุ่มบันทึก
                  ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: Icon(color: Colors.white, Icons.save_outlined),
                    label: Text(
                      _submitting ? 'กำลังบันทึก...' : 'บันทึกงาน',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
