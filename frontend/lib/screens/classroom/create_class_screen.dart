import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/models/classroom.dart';
import 'package:frontend/services/class_service.dart';
import 'package:frontend/utils/app_theme.dart';

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
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _nameCtl.text = e.name ?? '';
      _descCtl.text = e.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      if (widget.editing == null) {
        final body = ClassroomCreate(
          name: _nameCtl.text.trim(),
          description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(),
        );
        await ClassService.createClassroom(body);
      } else {
        final body = ClassroomUpdate(
          name: _nameCtl.text.trim(),
          description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(),
        );
        await ClassService.updateClassroom(widget.editing!.classId!, body);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;

    return Scaffold(
      body: Stack(
        children: [
          // ----------------------------------------------------
          // 1. ฉากหลังตามรูปแบบเป๊ะๆ (สีฟ้าพาสเทล + วงกลม Abstract)
          // ----------------------------------------------------
          Container(
            color: const Color(0xFFE8F0FE), // สีพื้นหลังฟ้าพาสเทลหลักของแอปคุณ
          ),
          // วงกลมซ้ายบน-กลาง
          Positioned(
            top: 160,
            left: -120,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD2E3FC).withOpacity(0.7), // วงกลมฟ้าที่เข้มขึ้นมาอีกเฉด
              ),
            ),
          ),
          // วงกลมขวาบน
          Positioned(
            top: -60,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD2E3FC).withOpacity(0.5),
              ),
            ),
          ),
          // วงกลมขวาขอบล่าง (ตรงปุ่ม FloatingActionButton เดิมของคุณ)
          Positioned(
            bottom: -100,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD2E3FC).withOpacity(0.8),
              ),
            ),
          ),

          // ----------------------------------------------------
          // 2. ตัวฟอร์มหน้าต่างกระจกฝ้า (Glassmorphic Form)
          // ----------------------------------------------------
          Positioned.fill(
            child: Scaffold(
              backgroundColor: Colors.transparent, // ต้องใสเพื่อให้เห็นพื้นหลัง Stack ข้างล่าง
              appBar: AppBar(
                backgroundColor: Colors.white.withOpacity(0.4), // AppBar กระจกใสกลมกลืนกับฉากหลัง
                elevation: 0,
                title: Text(
                  editing ? 'แก้ไขคลาส' : 'สร้างคลาส',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AbsorbPointer(
                    absorbing: _loading,
                    child: Center(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Container(
                            // เงาจางๆ สไตล์มินิมอล ไม่ดุดันเกินไป
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueGrey.withOpacity(0.1),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), // ระดับความฝ้าของกระจก
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.65), // ขาวสว่างขึ้นเพื่อให้อ่าน Text ง่าย
                                        Colors.white.withOpacity(0.30),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    // เส้นขอบสะท้อนแสงบางๆ
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(Icons.class_, color: Colors.white, size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  editing ? 'แก้ไขข้อมูลคลาส' : 'ตั้งค่าคลาสใหม่',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                const Text(
                                                  'ปรับข้อมูลพื้นฐานของห้องเรียน',
                                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        TextFormField(
                                          controller: _nameCtl,
                                          decoration: appInput(
                                            label: 'ชื่อคลาส',
                                            icon: Icons.class_,
                                            hint: 'กรอกชื่อคลาสของคุณ เช่น คณิตศาสตร์ ม.4/1',
                                          ),
                                          validator: (v) => (v == null || v.trim().isEmpty) ? 'กรอกชื่อคลาส' : null,
                                        ),
                                        const SizedBox(height: 14),
                                        TextFormField(
                                          controller: _descCtl,
                                          maxLines: 3,
                                          decoration: appInput(
                                            label: 'คำอธิบาย (ไม่บังคับ)',
                                            hint: 'กรอกคำอธิบายคลาสของคุณ',
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.primary, // ใช้สีธีมหลักของคุณเพื่อให้ปุ่มเด่นเด่นขึ้นมา
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size.fromHeight(46),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                          onPressed: _submit,
                                          icon: _loading
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(Icons.save),
                                          label: Text(editing ? 'บันทึกการแก้ไข' : 'สร้างห้องเรียน'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}