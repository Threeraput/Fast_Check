import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:frontend/services/live_attendance_ws_service.dart';
import 'package:frontend/services/user_service.dart';

class TeacherLiveAttendanceScreen extends StatefulWidget {
  final String sessionId;
  final String classId;

  const TeacherLiveAttendanceScreen({
    super.key,
    required this.sessionId,
    required this.classId,
  });

  @override
  State<TeacherLiveAttendanceScreen> createState() =>
      _TeacherLiveAttendanceScreenState();
}

class _TeacherLiveAttendanceScreenState
    extends State<TeacherLiveAttendanceScreen> {
  final _ws = LiveAttendanceWsService();

  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _pingTimer;

  bool _connecting = true;
  String? _error;

  DateTime? _startTime;
  DateTime? _endTime;
  String? _className;

  int _totalStudents = 0;
  int _checkedInCount = 0;
  int _waitingCount = 0;
  int _presentCount = 0;
  int _lateCount = 0;

  List<Map<String, dynamic>> _attendees = const [];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _sub?.cancel();
    _ws.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      final stream = await _ws.connect(sessionId: widget.sessionId);

      _sub = stream.listen(
        _handleEvent,
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _error = e.toString().replaceFirst('Exception: ', '');
            _connecting = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _connecting = false;
            _error ??= 'การเชื่อมต่อสิ้นสุดลง';
          });
        },
      );

      _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _ws.sendPing();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _handleEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    final type = (event['event'] ?? '').toString().toLowerCase();

    if (type == 'snapshot') {
      setState(() {
        _connecting = false;
        _error = null;

        _startTime = DateTime.tryParse((event['start_time'] ?? '').toString());
        _endTime = DateTime.tryParse((event['end_time'] ?? '').toString());
        _className = (event['class_name'] ?? '').toString();

        _totalStudents = _toInt(event['total_students']);
        _checkedInCount = _toInt(event['checked_in_count']);
        _waitingCount = _toInt(event['waiting_count']);

        final summary = _asMap(event['summary']);
        _presentCount = _toInt(summary['present']);
        _lateCount = _toInt(summary['late']);

        _attendees = _asList(event['attendees']);
      });
      return;
    }

    if (type == 'checkin_added') {
      setState(() {
        _connecting = false;
        _error = null;

        _checkedInCount = _toInt(event['checked_in_count']);
        _totalStudents = _toInt(event['total_students']);
        _waitingCount = _toInt(event['waiting_count']);

        final summary = _asMap(event['summary']);
        _presentCount = _toInt(summary['present']);
        _lateCount = _toInt(summary['late']);

        final item = _asMap(event['item']);
        if (item.isNotEmpty) {
          final key = (item['attendance_id'] ?? '').toString();
          if (key.isNotEmpty) {
            _attendees = [
              item,
              ..._attendees.where(
                (e) => (e['attendance_id'] ?? '').toString() != key,
              ),
            ];
          }
        }
      });
      return;
    }

    if (type == 'error') {
      final msg = (event['message'] ?? 'Unknown error').toString();
      setState(() {
        _connecting = false;
        _error = msg;
      });

      if (msg == 'Session not found') {
        // ถ้าไม่เจอ session ให้เด้งกลับ หรือบอกให้ชัดเจน
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบข้อมูลการเช็คชื่อนี้ในระบบ')),
          );
        }
      }
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      return v.map((k, value) => MapEntry(k.toString(), value));
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => _asMap(e)).where((e) => e.isNotEmpty).toList();
  }

  String _statusText(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
    switch (normalized) {
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
        return raw.isEmpty ? 'ไม่ระบุ' : raw;
    }
  }

  Color _statusColor(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Attendance'),
        actions: [
          IconButton(
            tooltip: 'Reconnect',
            onPressed: () async {
              await _sub?.cancel();
              await _ws.disconnect();
              _pingTimer?.cancel();
              _connect();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _connecting
          ? const Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 28, 178, 248),
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 42),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _sub?.cancel();
                        await _ws.disconnect();
                        _pingTimer?.cancel();
                        _connect();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reconnect'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _sub?.cancel();
                await _ws.disconnect();
                _pingTimer?.cancel();
                await _connect();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_className != null &&
                                    _className!.trim().isNotEmpty)
                                ? _className!.trim()
                                : 'Class ${widget.classId}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          if (_startTime != null)
                            Text(
                              'เริ่ม: ${dateFmt.format(_startTime!.toLocal())}',
                            ),
                          if (_endTime != null)
                            Text(
                              'สิ้นสุด: ${dateFmt.format(_endTime!.toLocal())}',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatChip(
                        label: 'ทั้งหมด',
                        value: _totalStudents,
                        color: Colors.blue,
                      ),
                      _StatChip(
                        label: 'เช็คชื่อแล้ว',
                        value: _checkedInCount,
                        color: Colors.indigo,
                      ),
                      _StatChip(
                        label: 'เข้าเรียน',
                        value: _presentCount,
                        color: Colors.green,
                      ),
                      _StatChip(
                        label: 'สาย',
                        value: _lateCount,
                        color: Colors.orange,
                      ),
                      _StatChip(
                        label: 'ยังไม่เช็คชื่อ',
                        value: _waitingCount,
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'รายชื่อที่เช็คชื่อแล้ว (${_attendees.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_attendees.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('ยังไม่มีนักเรียนเช็คชื่อใน session นี้'),
                      ),
                    )
                  else
                    ..._attendees.map((a) {
                      final checkIn = DateTime.tryParse(
                        (a['check_in_time'] ?? '').toString(),
                      );
                      final status = (a['status'] ?? '').toString();
                      final imageUrl = UserService.absoluteAvatarUrl(
                        a['face_image_path']?.toString(),
                      );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: imageUrl == null || imageUrl.isEmpty
                                  ? Container(
                                      color: _statusColor(
                                        status,
                                      ).withValues(alpha: 0.12),
                                      child: Icon(
                                        Icons.person,
                                        color: _statusColor(status),
                                      ),
                                    )
                                  : Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: _statusColor(
                                                status,
                                              ).withValues(alpha: 0.12),
                                              child: Icon(
                                                Icons.person,
                                                color: _statusColor(status),
                                              ),
                                            );
                                          },
                                    ),
                            ),
                          ),
                          title: Text(
                            (a['student_name'] ?? 'Unknown Student').toString(),
                          ),
                          subtitle: Text(
                            checkIn == null
                                ? 'ไม่พบเวลาเช็คชื่อ'
                                : 'เวลา ${dateFmt.format(checkIn.toLocal())}',
                          ),
                          trailing: Text(
                            _statusText(status),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _statusColor(status),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          '$value',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
