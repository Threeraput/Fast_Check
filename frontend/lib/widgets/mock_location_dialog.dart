import 'package:flutter/material.dart';

Future<void> showMockLocationDialog(
  BuildContext context, {
  String title = 'ตรวจพบตำแหน่งจำลอง',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.gps_off, size: 64, color: Colors.redAccent),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ระบบไม่อนุญาตให้ใช้งาน Fake GPS หรือ Mock Location',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'กรุณาปิดแอปจำลองตำแหน่ง แล้วลองใหม่อีกครั้ง',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(const Color.fromARGB(255, 231, 47, 34)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ตกลง'),
          ),
        ),
      ],
    ),
  );
}
