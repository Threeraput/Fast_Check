import 'package:flutter/material.dart';

class AttendanceStatusBadge extends StatelessWidget {
  final String status;
  final bool isManualOverride;

  const AttendanceStatusBadge({
    super.key,
    required this.status,
    this.isManualOverride = false,
  });

  static Color getStatusColor(String status) {
    final s = status.toLowerCase().replaceAll(' ', '_');
    switch (s) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      case 'left_early':
      case 'leftearly':
        return Colors.purple;
      case 'unverified_face':
        return Colors.blueGrey;
      case 'manual_override':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  static String getStatusText(String status) {
    final s = status.toLowerCase().replaceAll(' ', '_');
    switch (s) {
      case 'present':
        return 'เข้าเรียน';
      case 'late':
        return 'สาย';
      case 'absent':
        return 'ขาด';
      case 'left_early':
      case 'leftearly':
        return 'กลับก่อน';
      case 'unverified_face':
        return 'เช็คชื่อแล้ว';
      case 'manual_override':
        return 'แก้ไขโดยอาจารย์';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = getStatusColor(status);
    final text = getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isManualOverride) ...[
            const Icon(Icons.edit, size: 12, color: Colors.blue),
            const SizedBox(width: 4),
            const Text(
              '[Manual] ',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
