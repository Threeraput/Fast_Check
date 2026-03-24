import 'package:frontend/models/users.dart'; // <-- add this


class AdminUsersPage {
  final int total;
  final int limit;
  final int offset;
  final List<User> items;

  AdminUsersPage({
    required this.total,
    required this.limit,
    required this.offset,
    required this.items,
  });

  factory AdminUsersPage.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List? ?? []).cast<dynamic>();
    return AdminUsersPage(
      total: json['total'] ?? 0,
      limit: json['limit'] ?? 50,
      offset: json['offset'] ?? 0,
      items: list
          .map((e) => User.fromJson((e as Map<String, dynamic>)))
          .toList(),
    );
  }
}

class SystemSummary {
  final int totalUsers;
  final int totalAdmins;
  final int totalTeachers;
  final int totalStudents;
  final int totalClasses;
  final int totalAttendances;
  final int totalAttendancesInRange;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  SystemSummary({
    required this.totalUsers,
    required this.totalAdmins,
    required this.totalTeachers,
    required this.totalStudents,
    required this.totalClasses,
    required this.totalAttendances,
    required this.totalAttendancesInRange,
    this.rangeStart,
    this.rangeEnd,
  });

  factory SystemSummary.fromJson(Map<String, dynamic> json) {
    DateTime? _dt(v) =>
        (v == null || v.toString().isEmpty) ? null : DateTime.tryParse(v);
    return SystemSummary(
      totalUsers: json['total_users'] ?? 0,
      totalAdmins: json['total_admins'] ?? 0,
      totalTeachers: json['total_teachers'] ?? 0,
      totalStudents: json['total_students'] ?? 0,
      totalClasses: json['total_classes'] ?? 0,
      totalAttendances: json['total_attendances'] ?? 0,
      totalAttendancesInRange: json['total_attendances_in_range'] ?? 0,
      rangeStart: _dt(json['range_start']),
      rangeEnd: _dt(json['range_end']),
    );
  }
}
