import 'dart:ui'; 
import 'package:frontend/models/classroom.dart';
import 'package:frontend/services/admin_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/utils/app_theme.dart';
import 'package:flutter/material.dart';
import '../../services/class_service.dart'; 

class ArchivedClassesScreen extends StatefulWidget {
  const ArchivedClassesScreen({Key? key}) : super(key: key);

  @override
  State<ArchivedClassesScreen> createState() => _ArchivedClassesScreenState();
}

class _ArchivedClassesScreenState extends State<ArchivedClassesScreen> {
  List<Classroom> archivedClasses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchArchivedClasses();
  }

  Future<void> _fetchArchivedClasses() async {
    try {
      final tokenRoles = await AuthService.getTokenRoles();
      final isTeacherRole = tokenRoles.contains('teacher') || tokenRoles.contains('admin');
      List<Classroom> allClasses = [];

      if (tokenRoles.contains('admin')) {
        final page = await AdminService.listClasses(isArchived: true, limit: 200, offset: 0);
        allClasses = (page['items'] as List<dynamic>?)?.map((e) => Classroom.fromJson(e as Map<String, dynamic>)).toList() ?? [];
      } else if (isTeacherRole) {
        allClasses = await ClassService.getTaughtClasses(isArchived: true);
      } else {
        allClasses = await ClassService.getEnrolledClasses(isArchived: true);
      }

      if (!mounted) return;

      setState(() {
        archivedClasses = allClasses.where((c) => c.isArchived == true).toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  Future<void> _restoreClass(String classId) async {
    try {
      await ClassService.restoreClassroom(classId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กู้คืนคลาสสำเร็จ!'), backgroundColor: Colors.green),
      );
      _fetchArchivedClasses();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กู้คืนไม่สำเร็จ: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FE), // สีฟ้าพาสเทลหลักของแอป
      body: Stack(
        children: [
          // -----------------------------------------------------------------
          // 1. ฉากหลังกราฟิก (เพิ่มลวดลายให้ซับซ้อนขึ้นเพื่อให้เวลาเบลอแล้วเห็นเอฟเฟกต์กระจกชัดๆ)
          // -----------------------------------------------------------------
          Positioned(
            top: 100,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFD2E3FC), 
              ),
            ),
          ),
          Positioned(
            top: 300,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFC4DAFB), // ไล่เฉดให้เข้มขึ้นอีกนิดเพื่อให้ตัดกับกระจก
              ),
            ),
          ),

          // -----------------------------------------------------------------
          // 2. โครงสร้าง UI หลัก (เน้นทำกระจกแยกชิ้น และใส่เงา Drop Shadow ให้ลอยเด้งออกมา)
          // -----------------------------------------------------------------
          Positioned.fill(
            child: Scaffold(
              backgroundColor: Colors.transparent, // ต้องใสเพื่อให้เห็นลายข้างหลัง
              appBar: AppBar(
                title: const Text('ชั้นเรียนที่เก็บ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                backgroundColor: Colors.white.withOpacity(0.3), // AppBar กระจกฝ้าบางๆ
                elevation: 0,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              body: isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : archivedClasses.isEmpty
                      ? _buildEmptyState()
                      : _buildGlassCardListView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 42, color: AppColors.textSecondary),
                    SizedBox(height: 16),
                    Text(
                      'ไม่มีชั้นเรียนที่ถูกเก็บ',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
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

  // ลิสต์รายการแบบแยกชิ้น (เห็นกระจกฝ้าชัดเจน 100% เพราะมีขอบเงาตัดและเห็นพื้นหลังทะลุระหว่างช่อง)
  Widget _buildGlassCardListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: archivedClasses.length,
      itemBuilder: (context, index) {
        final classData = archivedClasses[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14), // เว้นช่องไฟให้เห็นฉากหลังทะลุผ่าน
          child: Container(
            // เพิ่มเงาละมุน (Drop Shadow) เพื่อยกตัวกระจกให้ลอยแยกชั้นออกจากพื้นหลัง
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withOpacity(0.06), // เงาสีน้ำเงินเข้มจางๆ
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), // เพิ่มความเบลอให้เห็นเนื้อวุ้นกระจก
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    // ใช้การไล่เฉดสีขาวโปร่งแสงเพื่อจำลองมุมตกกระทบของแสงบนกระจก
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.55),
                        Colors.white.withOpacity(0.20),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    // เส้นขอบสะท้อนแสง (Specular Border) ช่วยเน้นขอบเขตการ์ดกระจกแต่ละใบ
                    border: Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withOpacity(0.5),
                      child: const Icon(Icons.archive_outlined, color: AppColors.textSecondary, size: 18),
                    ),
                    title: Text(
                      classData.name ?? 'ไม่มีชื่อคลาส',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      'รหัสคลาส: ${classData.code ?? '-'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: FilledButton.tonalIcon(
                      onPressed: classData.classId == null ? null : () => _restoreClass(classData.classId!),
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('กู้คืน'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.successLight.withOpacity(0.8),
                        foregroundColor: AppColors.success,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}