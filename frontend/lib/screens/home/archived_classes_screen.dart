import 'package:flutter/material.dart';
import 'package:frontend/models/classroom.dart';
import '../../services/class_service.dart'; // 2. นำเข้าคนส่งของ

class ArchivedClassesScreen extends StatefulWidget {
  const ArchivedClassesScreen({Key? key}) : super(key: key);

  @override
  State<ArchivedClassesScreen> createState() => _ArchivedClassesScreenState();
}

class _ArchivedClassesScreenState extends State<ArchivedClassesScreen> {
  // สร้างตัวแปรไว้เก็บรายชื่อห้องที่ถูกซ่อน
  List<Classroom> archivedClasses = []; 
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchArchivedClasses();
  }

  // ฟังก์ชันสำหรับดึงข้อมูลจาก API
  Future<void> _fetchArchivedClasses() async {
    try {
      // เรียกใช้ Service ฝั่งหน้าบ้าน ไปขอดึงรายชื่อวิชาที่ครูคนนี้สอนทั้งหมด
      final List<Classroom> allClasses = await ClassService.getTaughtClasses(isArchived: true);
      
      if (!mounted) return;

      setState(() {
        // กรองเอาเฉพาะห้องที่โดนซ่อน (isArchived == true)
        archivedClasses = allClasses.where((c) => c.isArchived == true).toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      
      // แสดงแจ้งเตือนถ้าดึงข้อมูลพลาด
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  // ฟังก์ชันกดกู้คืนคลาส
  Future<void> _restoreClass(String classId) async {
    try {
      // 1. เรียก API กู้คืน
      await ClassService.restoreClassroom(classId);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กู้คืนคลาสสำเร็จ!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 2. โหลดข้อมูลใหม่ เพื่อให้ห้องที่เพิ่งกู้คืนหายไปจากหน้านี้
      _fetchArchivedClasses(); 

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กู้คืนไม่สำเร็จ: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ชั้นเรียนที่เก็บ'),
        backgroundColor: Colors.blueGrey, // ให้สีดูแตกต่างจากหน้าหลัก
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : archivedClasses.isEmpty
              ? const Center(
                  child: Text(
                    'ไม่มีชั้นเรียนที่ถูกเก็บ',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: archivedClasses.length,
                  itemBuilder: (context, index) {
                    final classData = archivedClasses[index];
                    return Card(
                      color: Colors.grey.shade200, // สีการ์ดหม่นๆ ให้ดูเหมือนถูกเก็บ
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        // ป้องกันกรณีชื่อเป็น null
                        title: Text(
                          classData.name ?? 'ไม่มีชื่อคลาส',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ), 
                        subtitle: Text('รหัส: ${classData.code ?? '-'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.restore, color: Colors.green),
                          tooltip: 'กู้คืนคลาสนี้',
                          onPressed: () {
                            // ป้องกันกรณี classId เป็น null
                            if (classData.classId != null) {
                              _restoreClass(classData.classId!);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}