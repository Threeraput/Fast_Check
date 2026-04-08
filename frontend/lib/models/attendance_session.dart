import 'dart:convert';

class AttendanceSession {
  final String sessionId;
  final String classId;
  final String teacherId;

  /// เวลาเริ่ม (ยอมรับได้ทั้ง opened_at หรือ start_time)
  final DateTime openedAt;

  /// เวลาสิ้นสุด (ยอมรับได้ทั้ง expires_at หรือ end_time)
  final DateTime? expiresAt;

  final double anchorLat;
  final double anchorLon;
  final double radiusMeters;

  /// บางระบบมี is_closed (ถ้า backend ไม่มีจะบังคับเป็น false)
  final bool isClosed;

  /// 🔹 ธงเปิดรอบยืนยันซ้ำ (เพิ่มใหม่)
  final bool reverifyEnabled;

  AttendanceSession({
    required this.sessionId,
    required this.classId,
    required this.teacherId,
    required this.openedAt,
    required this.expiresAt,
    required this.anchorLat,
    required this.anchorLon,
    required this.radiusMeters,
    required this.isClosed,
    required this.reverifyEnabled,
  });

  /// Getter: session ยัง active อยู่ไหม (ตามเวลาปัจจุบัน UTC + isClosed)
  bool get isActive {
    final nowUtc = DateTime.now().toUtc();
    final notExpired = (expiresAt == null) || expiresAt!.isAfter(nowUtc);
    return !isClosed && notExpired;
  }

  /// Helper: เปิดปุ่ม "ยืนยันซ้ำ" ได้ไหม (ใช้แนวคิด time-window เดียวกับ session)
  bool canReverify({DateTime? nowUtc}) {
    final t = nowUtc ?? DateTime.now().toUtc();
    final notExpired = (expiresAt == null) || expiresAt!.isAfter(t);
    return reverifyEnabled && notExpired;
  }

  static T? _firstNonNull<T>(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      if (j.containsKey(k) && j[k] != null) return j[k] as T;
    }
    return null;
  }

  static DateTime _parseDateTime(String v) => DateTime.parse(v);

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.parse(v);
    throw ArgumentError('Invalid numeric value: $v');
  }

  factory AttendanceSession.fromJson(Map<String, dynamic> j) {
    // รองรับหลายชื่อ key
    final sessionId = _firstNonNull<String>(j, [
      'session_id',
      'id',
      'sessionId',
    ])!;
    final classId = _firstNonNull<String>(j, ['class_id', 'classId'])!;
    final teacherId = _firstNonNull<String>(j, ['teacher_id', 'teacherId'])!;

    final openedAtStr = _firstNonNull<String>(j, [
      'opened_at',
      'start_time',
      'openedAt',
      'startTime',
    ]);
    if (openedAtStr == null) {
      throw ArgumentError('opened_at/start_time is required');
    }

    final expiresStr = _firstNonNull<String>(j, [
      'expires_at',
      'end_time',
      'expiresAt',
      'endTime',
    ]);

    final anchorLatRaw = _firstNonNull(j, ['anchor_lat', 'anchorLat']);
    final anchorLonRaw = _firstNonNull(j, ['anchor_lon', 'anchorLon']);
    final radiusRaw = _firstNonNull(j, ['radius_meters', 'radiusMeters']);

    final isClosed =
        (_firstNonNull(j, ['is_closed', 'isClosed']) ?? false) == true;

    final reverifyEnabled =
        (_firstNonNull(j, ['reverify_enabled', 'reverifyEnabled']) ?? false) ==
        true;

    return AttendanceSession(
      sessionId: sessionId,
      classId: classId,
      teacherId: teacherId,
      openedAt: _parseDateTime(openedAtStr),
      expiresAt: (expiresStr != null) ? _parseDateTime(expiresStr) : null,
      anchorLat: _toDouble(anchorLatRaw),
      anchorLon: _toDouble(anchorLonRaw),
      radiusMeters: _toDouble(radiusRaw),
      isClosed: isClosed,
      reverifyEnabled: reverifyEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'class_id': classId,
    'teacher_id': teacherId,
    // คงใช้ชื่อเดิมฝั่งคุณ: opened_at / expires_at
    'opened_at': openedAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'anchor_lat': anchorLat,
    'anchor_lon': anchorLon,
    'radius_meters': radiusMeters,
    'is_closed': isClosed,
    // 🔹 ส่งฟิลด์ใหม่กลับไปด้วย (ถ้าจำเป็น)
    'reverify_enabled': reverifyEnabled,
  };

  AttendanceSession copyWith({
    String? sessionId,
    String? classId,
    String? teacherId,
    DateTime? openedAt,
    DateTime? expiresAt,
    double? anchorLat,
    double? anchorLon,
    double? radiusMeters,
    bool? isClosed,
    bool? reverifyEnabled,
  }) {
    return AttendanceSession(
      sessionId: sessionId ?? this.sessionId,
      classId: classId ?? this.classId,
      teacherId: teacherId ?? this.teacherId,
      openedAt: openedAt ?? this.openedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      anchorLat: anchorLat ?? this.anchorLat,
      anchorLon: anchorLon ?? this.anchorLon,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isClosed: isClosed ?? this.isClosed,
      reverifyEnabled: reverifyEnabled ?? this.reverifyEnabled,
    );
  }
}
