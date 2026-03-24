// lib/screens/teacher_open_checkin_sheet.dart
import 'package:flutter/material.dart';
// ใช้ SessionsService ให้ตรงกับส่วนอื่นของแอป
import 'package:frontend/services/sessions_service.dart';
import 'package:numberpicker/numberpicker.dart';
import '../utils/location_helper.dart';
import 'package:frontend/services/attendance_service.dart';

class TeacherOpenCheckinSheet extends StatefulWidget {
  final String classId;
  const TeacherOpenCheckinSheet({super.key, required this.classId});

  @override
  State<TeacherOpenCheckinSheet> createState() =>
      _TeacherOpenCheckinSheetState();
}

class _TeacherOpenCheckinSheetState extends State<TeacherOpenCheckinSheet> {
  final _minCtl = TextEditingController(text: '15');
  final _lateCtl = TextEditingController(text: '10'); // เวลาตัดสาย (นาที)
  final _radiusCtl = TextEditingController(text: '100');
  final _formKey = GlobalKey<FormState>();
  bool _posting = false;

  @override
  void dispose() {
    _minCtl.dispose();
    _lateCtl.dispose();
    _radiusCtl.dispose();
    super.dispose();
  }

  String? _requiredInt(String? v, {int min = 1, int max = 1440}) {
    if (v == null || v.trim().isEmpty) return 'กรอกตัวเลข';
    final n = int.tryParse(v.trim());
    if (n == null) return 'ต้องเป็นตัวเลข';
    if (n < min || n > max) return 'ระหว่าง $min–$max';
    return null;
  }

  String? _lateCutoffValidator(String? v) {
    final base = _requiredInt(v, min: 1, max: 1440);
    if (base != null) return base;
    final minutes = int.tryParse(_minCtl.text.trim());
    final cutoff = int.tryParse(v!.trim());
    if (minutes != null && cutoff != null && cutoff > minutes) {
      return 'ต้องไม่เกินเวลาหมดอายุ (${minutes} นาที)';
    }
    return null;
  }

 Future<void> _open() async {
    if (!_formKey.currentState!.validate()) return;

    final minutes = int.parse(_minCtl.text.trim());
    final cutoff = int.parse(_lateCtl.text.trim());
    final radius = int.parse(_radiusCtl.text.trim());

    if (cutoff > minutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เวลาตัดสายต้องไม่เกินเวลาหมดอายุ')),
      );
      return;
    }

    setState(() => _posting = true);
    try {
      final pos = await LocationHelper.getCurrentPositionOrThrow();

      // เรียกเปิด session (ได้ AttendanceSession กลับมา)
      final s = await AttendanceService.openSession(
        classId: widget.classId,
        expiresInMinutes: minutes,
        radiusMeters: radius,
        latitude: pos.latitude,
        longitude: pos.longitude,
        lateCutoffMinutes: cutoff,
      );

      if (!mounted) return;

      // ✅ แปลงเป็น Map ส่งกลับไปให้หน้าแม่ทำ optimistic UI
      // (พยายามใส่ทั้งคีย์ที่ FeedService/ActiveSessionsBanner รองรับ)
      final created = <String, dynamic>{
        'session_id':
            ( /* ถ้าโมเดลมี field id */ (() {
              try {
                return (s as dynamic).id?.toString();
              } catch (_) {
                return null;
              }
            })()) ??
            '',
        'id': (() {
          try {
            return (s as dynamic).id?.toString();
          } catch (_) {
            return null;
          }
        })(),
        'class_id': widget.classId,
        'start_time': (() {
          try {
            return (s as dynamic).startTime?.toIso8601String();
          } catch (_) {
            return null;
          }
        })(),
        'end_time': (() {
          try {
            return (s as dynamic).endTime?.toIso8601String();
          } catch (_) {
            return null;
          }
        })(),
        'expires_at': (() {
          // เผื่อฝั่งแสดงผลดู expires_at
          try {
            return (s as dynamic).endTime?.toIso8601String();
          } catch (_) {
            return null;
          }
        })(),
        'reverify_enabled': (() {
          try {
            return (s as dynamic).reverifyEnabled == true;
          } catch (_) {
            return false;
          }
        })(),
        'radius_meters': (() {
          try {
            return (s as dynamic).radiusMeters;
          } catch (_) {
            return radius;
          }
        })(),
        'anchor_lat': (() {
          try {
            return (s as dynamic).anchorLat;
          } catch (_) {
            return pos.latitude;
          }
        })(),
        'anchor_lon': (() {
          try {
            return (s as dynamic).anchorLon;
          } catch (_) {
            return pos.longitude;
          }
        })(),
      };

      // ถ้าไม่มี id เลย ให้ fallback เป็นเวลาเพื่อไม่ให้การ์ดหลุด (ยังไงก็จะ refresh ทับภายหลัง)
      if ((created['session_id']?.toString().isEmpty ?? true) &&
          (created['id']?.toString().isEmpty ?? true)) {
        created['session_id'] =
            '${widget.classId}-${DateTime.now().millisecondsSinceEpoch}';
      }

      // ส่ง Map กลับไป (แทน true) เพื่อให้หน้าแม่ insertOptimisticSession()
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('🧩 [TeacherOpenCheckinSheet] error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'ประกาศเช็คชื่อ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // หมดอายุใน (นาที)
            TextFormField(
              readOnly: true,
              controller: _minCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'หมดอายุใน (นาที)',
                border: OutlineInputBorder(),
                helperText: 'เช่น 15 นาที',
                suffixIcon: Icon(Icons.timer_outlined),
              ),
              onTap: () async {
              int currentValue = int.tryParse(_minCtl.text) ?? 15;
              int tempValue = currentValue;

await showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (context) {
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('เลือกเวลาหมดอายุ (นาที)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: NumberPicker(
                  value: tempValue,
                  minValue: 1,
                  maxValue: 240,
                  onChanged: (val) => setModalState(() => tempValue = val),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      style: TextStyle(color: Colors.grey),
                      'ยกเลิก'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    onPressed: () {
                      setState(() => _minCtl.text = tempValue.toString());
                      Navigator.pop(context);
                    },
                    child: const Text('ตกลง'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  },
);
              },
              validator: (v) => _requiredInt(v, min: 1, max: 240),
            ),
            const SizedBox(height: 12),

            // เวลาตัดสาย (นาทีหลังเริ่ม)
            TextFormField(
              readOnly: true,
              controller: _lateCtl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'เวลาตัดสาย (นาทีหลังเริ่ม)',
                border: const OutlineInputBorder(),
                helperText:
                    'เช่น 10 นาที (ต้องไม่เกินเวลาหมดอายุ ${_minCtl.text} นาที)',
              suffixIcon: Icon(Icons.timer_off_outlined),
              ),
              onTap: () async {
              int currentValue = int.tryParse(_lateCtl.text) ?? 15;
              int tempValue = currentValue;

await showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (context) {
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('เลือกเวลาหมดอายุ (นาที)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: NumberPicker(
                  value: tempValue,
                  minValue: 1,
                  maxValue: 240,
                  onChanged: (val) => setModalState(() => tempValue = val),
                ),
              ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      style: TextStyle(color: Colors.grey),
                      'ยกเลิก'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    onPressed: () {
                      setState(() => _lateCtl.text = tempValue.toString());
                      Navigator.pop(context);
                    },
                    child: const Text('ตกลง'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  },
);
              },
              validator: (v) => _lateCutoffValidator(v)
            ),
            const SizedBox(height: 12),

            // รัศมี (เมตร)
            TextFormField(
              controller: _radiusCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'รัศมี (เมตร)',
                border: OutlineInputBorder(),
                helperText: 'เช่น 100 เมตร',
              ),
              validator: (v) => _requiredInt(v, min: 10, max: 2000),
            ),

            const SizedBox(height: 16),
            FilledButton.icon(
              
              onPressed: _posting ? null : _open,
              icon: const Icon(Icons.play_circle_outline),
              label: _posting
                  ? const Text('กำลังเปิด...')
                  : const Text('เริ่มเช็คชื่อ'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
