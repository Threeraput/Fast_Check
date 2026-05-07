import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/announcement_service.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  final String classId;
  final String className;

  const CreateAnnouncementScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _titleCtl = TextEditingController();
  final _bodyCtl = TextEditingController();
  bool _posting = false;
  bool _success = false;

  // เพิ่มตัวเลือกเสริม
  bool _pinned = false;
  bool _visible = true;
  DateTime? _expiresAt;

  @override
  void dispose() {
    _titleCtl.dispose();
    _bodyCtl.dispose();
    super.dispose();
  }

  Future<void> _pickExpireDateTime() async {
    final now = DateTime.now();
    final init = _expiresAt ?? now.add(const Duration(days: 7));

    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (BuildContext context, Widget? child) {
         return Theme(
          data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Colors.blue, // สีวงกลมวันที่เลือก
            onPrimary: Colors.white, // สีตัวเลขในวงกลม
            surface: Colors.white, // พื้นหลัง popup
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue, // สีปุ่ม Cancel / OK
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        child: child!,
      );
    },
  );
    if (d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(init),
      builder: (BuildContext context, Widget? child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.lightBlue, // สีไฮไลต์วงกลมรอบตัวเลข
            secondary: Colors.lightBlueAccent, // สีเวลาที่เลือก
            onPrimary: Colors.white, // สีตัวเลขในวงกลม
            surface: Colors.white,
            onSurface: Colors.black87, // สีข้อความทั่วไป
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue, // สีปุ่ม Cancel / OK
            ),
          ),
        ),
        child: child!,
      );
    }, 
    );
    if (t == null) return;

    setState(() {
      _expiresAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _post() async {
    final title = _titleCtl.text.trim();
    final body = _bodyCtl.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรอกหัวข้อประกาศ')));
      return;
    }

    setState(() => _posting = true);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      await AnnouncementService.create(
        classId: widget.classId,
        title: title,
        body: body.isEmpty ? null : body,
        pinned: _pinned,
        visible: _visible,
        expiresAt:
            _expiresAt, // ส่งเป็น DateTime? (ให้ service แปลงเป็น ISO8601)
      );

      if (!mounted) return;
      // ให้หน้าก่อนหน้ารู้ว่าทำสำเร็จแล้วไป refresh เอง
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('สร้างประกาศไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _success = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // เพิ่ม listener เพื่ออัปเดตตัวอย่างแบบเรียลไทม์
    _titleCtl.addListener(() => setState(() {}));
    _bodyCtl.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy HH:mm');
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar( 
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🔹 หัวข้อใหญ่
                  Row(
                    children: [
                      const Icon(
                        Icons.campaign_outlined,
                        color: Colors.blueAccent,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'สร้างประกาศใหม่',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 🔹 หัวข้อประกาศ
                  TextField(
                    controller: _titleCtl,
                    textInputAction: TextInputAction.next,
                    maxLines: 1,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.article_outlined),
                      labelText: 'หัวข้อ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 🔹 รายละเอียดประกาศ
                  TextField(
                    controller: _bodyCtl,
                    maxLines: null,
                    decoration: InputDecoration(
                      labelText: 'รายละเอียด',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🔹 ตัวเลือกเพิ่มเติม
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _pinned,
                          onChanged: (v) =>
                              setState(() => _pinned = v ?? false),
                          title: const Text('ปักหมุด (Pinned)'),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: Colors.blueAccent, // สีเมื่อถูกเลือก
                          checkColor: Colors.white,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _visible,
                          onChanged: (v) => setState(() => _visible = v),
                          title: const Text('แสดงให้นักเรียนเห็น'),
                          contentPadding: EdgeInsets.zero,
                          activeColor:
                              Colors.blueAccent, // สีของสวิตช์ตอนเปิด
                          activeTrackColor: Colors
                              .blue[100], // สีพื้นหลังตอนเปิด (อ่อนกว่า)
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 🔹 วันหมดอายุ (ไม่บังคับ)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'วันหมดอายุ (ไม่บังคับ)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _expiresAt == null
                                    ? '— ไม่ตั้งหมดอายุ —'
                                    : '${df.format(_expiresAt!.toLocal())}  ${TimeOfDay.fromDateTime(_expiresAt!).format(context)}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 36, // 🔹 ลดขนาดปุ่มลง
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              color: Colors.grey,
                              Icons.event,
                              size: 18,
                            ),
                            label: const Text(
                              'ตั้งเวลา',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: _pickExpireDateTime,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              side: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 🔹 ปุ่มโพสต์
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _posting ? null : _post,
                    icon: const Icon(Icons.send_rounded),
                    label: _posting
                        ? const Text('กำลังโพสต์...')
                        : const Text(
                            'โพสต์ประกาศ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),

                  // 🔹 แสดงสถานะการโพสต์
                  if (_posting)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.blue,
                              strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'กำลังโพสต์...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                  if (_success)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        children: const [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 48,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'โพสต์สำเร็จ!',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // // 🔹 Preview ตัวอย่างโพสต์
                  //  Padding(
                  //   padding: const EdgeInsets.only(top: 24),
                  //   child: AnimatedContainer(
                  //     duration: const Duration(milliseconds: 300),
                  //     curve: Curves.easeInOut,
                  //     child: Card(
                  //       color: Colors.blue.shade50,
                  //       shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(12)),
                  //       elevation: 0,
                  //       child: Padding(
                  //         padding: const EdgeInsets.all(16),
                  //         child: Column(
                  //           crossAxisAlignment: CrossAxisAlignment.start,
                  //           children: [
                  //             Row(
                  //               children: const [
                  //                 Icon(Icons.visibility,
                  //                     color: Colors.blueAccent),
                  //                 SizedBox(width: 6),
                  //                 Text(
                  //                   'ตัวอย่างโพสต์',
                  //                   style: TextStyle(
                  //                       fontWeight: FontWeight.bold,
                  //                       color: Colors.blueAccent),
                  //                 ),
                  //               ],
                  //             ),
                  //             const SizedBox(height: 12),
                  //             Text(
                  //               _titleCtl.text.isEmpty
                  //                   ? 'หัวข้อประกาศ'
                  //                   : _titleCtl.text,
                  //               style: const TextStyle(
                  //                   fontWeight: FontWeight.bold, fontSize: 16),
                  //             ),
                  //             const SizedBox(height: 8),
                  //             Text(
                  //               _bodyCtl.text.isEmpty
                  //                   ? 'รายละเอียด...'
                  //                   : _bodyCtl.text,
                  //               style: const TextStyle(
                  //                   fontSize: 14, color: Colors.black87),
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
