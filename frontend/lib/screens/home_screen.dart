// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/screens/classroom_home_screen.dart';
import '../services/auth_service.dart';
import '../models/users.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? _currentUser;
  bool _isAdmin = false; // เพิ่มตัวแปรเพื่อตรวจสอบว่าเป็น Admin หรือไม่

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getCurrentUserFromLocal();
    setState(() {
      _currentUser = user;
      // ตรวจสอบ roles ของผู้ใช้ว่ามี 'admin' หรือไม่
      _isAdmin = user?.roles.contains('admin') ?? false;
    });
  }

  Future<void> _logout() async {
    await AuthService.logout();
    Navigator.of(context).pushReplacementNamed('/login'); // กลับไปหน้า Login
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Screen'),
        actions: [
          // แสดงปุ่ม "Admin" เฉพาะเมื่อผู้ใช้เป็น Admin
          if (_isAdmin)
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/admin-dashboard');
              },
              child: Text('Admin', style: TextStyle(color: Colors.cyanAccent)),
            ),
          // ปุ่ม Logout
          IconButton(icon: Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_currentUser == null)
              Text('Loading user data...')
            else ...[
              Text(
                'Welcome, ${_currentUser!.firstName ?? _currentUser!.username}!',
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(height: 10),
              Text('Username: ${_currentUser!.username}'),
              if (_currentUser!.email != null)
                Text('Email: ${_currentUser!.email}'),
              if (_currentUser!.studentId != null)
                Text('Student ID: ${_currentUser!.studentId}'),
              if (_currentUser!.teacherId != null)
                Text('Teacher ID: ${_currentUser!.teacherId}'),
              Text('Roles: ${_currentUser!.roles.join(', ')}'),
              SizedBox(height: 30),
            ],
              ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('อัปโหลดใบหน้า'),
              onPressed: () => Navigator.pushNamed(context, '/upload-face'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.verified_user),
              label: const Text('ยืนยันตัวตนด้วยใบหน้า'),
              onPressed: () => Navigator.pushNamed(context, '/verify-face'),
            ),
    ElevatedButton(
      child: const Text('ไปยัง Classroom'),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ClassroomHomeScreen()),
        );
      },
    ),
  ],
        ),
      ),
    );
  }
}
