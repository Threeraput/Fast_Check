// lib/screens/teacher_open_checkin_sheet.dart
import 'package:flutter/material.dart';
import 'package:frontend/utils/app_theme.dart';
import 'package:flutter/services.dart'; // เพิ่มบรรทัดนี้
import 'package:numberpicker/numberpicker.dart';
import '../../utils/location_helper.dart';
import 'package:frontend/services/attendance_service.dart';
import '../../widgets/mock_location_dialog.dart';

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

  Future<int?> _pickMinutesDialog({
    required String title,
    required int initialValue,
    required int minValue,
    required int maxValue,
  }) async {
    int tempValue = initialValue.clamp(minValue, maxValue);

    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: StatefulBuilder(
            builder: (context, setModalState) {
              return SizedBox(
                height: 180,
                width: 220,
                child: NumberPicker(
                  value: tempValue,
                  minValue: minValue,
                  maxValue: maxValue,
                  onChanged: (val) => setModalState(() => tempValue = val),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(tempValue),
              child: const Text('ตกลง'),
            ),
          ],
        );
      },
    );
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

      // แปลงเป็น Map ส่งกลับไปให้หน้าแม่ทำ optimistic UI
      // ใช้ค่า sessionId จากโมเดลโดยตรง เพื่อให้ปุ่ม Live ใช้ UUID จริงทันที
      final created = <String, dynamic>{
        'session_id': s.sessionId,
        'id': s.sessionId,
        'class_id': s.classId,
        'start_time': s.openedAt.toIso8601String(),
        'end_time': s.expiresAt?.toIso8601String(),
        'expires_at': s.expiresAt?.toIso8601String(),
        'reverify_enabled': s.reverifyEnabled,
        'radius_meters': s.radiusMeters,
        'anchor_lat': s.anchorLat,
        'anchor_lon': s.anchorLon,
      };

      // ส่ง Map กลับไป (แทน true) เพื่อให้หน้าแม่ insertOptimisticSession()
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      if (LocationHelper.isMockLocationError(e)) {
        await showMockLocationDialog(
          context,
          title: 'ตรวจพบ Mock GPS ',
        );
        return;
      }
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
                final currentValue = int.tryParse(_minCtl.text) ?? 15;
                final picked = await _pickMinutesDialog(
                  title: 'เลือกเวลาหมดอายุ (นาที)',
                  initialValue: currentValue,
                  minValue: 1,
                  maxValue: 240,
                );

                if (!mounted || picked == null) return;
                setState(() {
                  _minCtl.text = picked.toString();
                  final late = int.tryParse(_lateCtl.text);
                  if (late != null && late > picked) {
                    _lateCtl.text = picked.toString();
                  }
                });
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
                final maxCutoff = int.tryParse(_minCtl.text) ?? 240;
                final currentValue = int.tryParse(_lateCtl.text) ?? 10;
                final picked = await _pickMinutesDialog(
                  title: 'เลือกเวลาตัดสาย (นาที)',
                  initialValue: currentValue,
                  minValue: 1,
                  maxValue: maxCutoff.clamp(1, 240),
                );

                if (!mounted || picked == null) return;
                setState(() => _lateCtl.text = picked.toString());
              },
              validator: (v) => _lateCutoffValidator(v),
            ),
            const SizedBox(height: 12),

            // รัศมี (เมตร)
            TextFormField(
              controller: _radiusCtl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter
                    .digitsOnly, // อนุญาตเฉพาะตัวเลขเท่านั้น
              ],
              decoration: const InputDecoration(
                labelText: 'รัศมี (เมตร)',
                border: OutlineInputBorder(),
                helperText: 'เช่น 100 เมตร (ขั้นต่ำ 1 เมตร)',
                suffixText: 'เมตร',
              ),
              validator: (v) =>
                  _requiredInt(v, min: 1, max: 2000), // เปลี่ยนขั้นต่ำเป็น 1
            ),

            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _posting ? null : _open,
              icon: const Icon(Icons.play_circle_outline),
              label: _posting
                  ? const Text('กำลังเปิด...')
                  : const Text('เริ่มเช็คชื่อ'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
