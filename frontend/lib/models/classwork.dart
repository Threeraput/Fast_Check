// lib/models/classwork.dart
import 'dart:convert';

/// ===============================
/// Enums & helpers
/// ===============================

/// สถานะความตรงเวลาในการส่งงาน (backend ส่ง: "On_Time", "Late", "Not_Submitted")
enum SubmissionLateness { onTime, late, notSubmitted }

SubmissionLateness latenessFromString(String? v) {
  switch (v) {
    case 'On_Time':
      return SubmissionLateness.onTime;
    case 'Late':
      return SubmissionLateness.late;
    case 'Not_Submitted':
    default:
      return SubmissionLateness.notSubmitted;
  }
}

String latenessToString(SubmissionLateness v) {
  switch (v) {
    case SubmissionLateness.onTime:
      return 'On_Time';
    case SubmissionLateness.late:
      return 'Late';
    case SubmissionLateness.notSubmitted:
      return 'Not_Submitted';
  }
}

/// ===============================
/// Core Models
/// ===============================

/// การส่งงานของนักเรียน (ระเบียนเต็มจากตาราง submissions)
class ClassworkSubmission {
  final String submissionId;
  final String assignmentId;
  final String studentId;
  
  final String? contentUrl; // เช่น "workpdf/<uuid>.pdf"
  final DateTime? submittedAt;

  final SubmissionLateness submissionStatus;
  final bool graded;
  final int? score;

  final DateTime createdAt;
  final DateTime updatedAt;

  ClassworkSubmission({
    required this.submissionId,
    required this.assignmentId,
    required this.studentId,
    required this.contentUrl,
    required this.submittedAt,
    required this.submissionStatus,
    required this.graded,
    required this.score,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClassworkSubmission.fromJson(Map<String, dynamic> j) {
    DateTime? _parseDt(dynamic s) {
      if (s == null) return null;
      return DateTime.tryParse(s.toString())?.toLocal();
    }

    return ClassworkSubmission(
      submissionId: j['submission_id']?.toString() ?? '',
      assignmentId: j['assignment_id']?.toString() ?? '',
      studentId: j['student_id']?.toString() ?? '',
      contentUrl: j['content_url']?.toString(),
      submittedAt: _parseDt(j['submitted_at']),
      submissionStatus: latenessFromString(j['submission_status']?.toString()),
      graded: j['graded'] == true,
      score: (j['score'] is num)
          ? (j['score'] as num).toInt()
          : (j['score'] as int?),
      createdAt:
          DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(j['updated_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'submission_id': submissionId,
    'assignment_id': assignmentId,
    'student_id': studentId,
    'content_url': contentUrl,
    'submitted_at': submittedAt?.toUtc().toIso8601String(),
    'submission_status': latenessToString(submissionStatus),
    'graded': graded,
    'score': score,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

/// งานของคลาส
class ClassworkAssignment {
  final String assignmentId;
  final String classId;
  final String teacherId;

  final String title;
  final int maxScore;
  final DateTime dueDate;

  final DateTime createdAt;
  final DateTime updatedAt;

  ClassworkAssignment({
    required this.assignmentId,
    required this.classId,
    required this.teacherId,
    required this.title,
    required this.maxScore,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClassworkAssignment.fromJson(Map<String, dynamic> j) {
    return ClassworkAssignment(
      assignmentId: j['assignment_id']?.toString() ?? '',
      classId: j['class_id']?.toString() ?? '',
      teacherId: j['teacher_id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      maxScore: (j['max_score'] is num)
          ? (j['max_score'] as num).toInt()
          : (j['max_score'] as int? ?? 100),
      dueDate:
          DateTime.tryParse(j['due_date']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(j['updated_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'assignment_id': assignmentId,
    'class_id': classId,
    'teacher_id': teacherId,
    'title': title,
    'max_score': maxScore,
    'due_date': dueDate.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

/// มุมมองฝั่งนักเรียน: งาน + สถานะของฉัน (my_submission) + computed_status
/// รองรับทั้งรูปแบบ flatten และ nested {"assignment": {...}}
class StudentAssignmentView {
  final ClassworkAssignment assignment;
  final SubmissionLateness computedStatus;
  final ClassworkSubmission? mySubmission;

  StudentAssignmentView({
    required this.assignment,
    required this.computedStatus,
    required this.mySubmission,
  });

  factory StudentAssignmentView.fromJson(Map<String, dynamic> j) {
    // ตรวจสอบว่าเป็นแบบ A (flatten) หรือแบบ B (มี key "assignment")
    final hasNested = j['assignment'] is Map<String, dynamic>;
    final Map<String, dynamic> assignJson = hasNested
        ? (j['assignment'] as Map<String, dynamic>)
        : j;

    final assignment = ClassworkAssignment.fromJson(assignJson);

    final my = j['my_submission'];
    ClassworkSubmission? mySub;
    if (my is Map<String, dynamic>) {
      mySub = ClassworkSubmission.fromJson(my);
    } else {
      mySub = null;
    }

    final statusStr =
        j['computed_status']?.toString() ??
        assignJson['computed_status']?.toString() ??
        'Not_Submitted';

    return StudentAssignmentView(
      assignment: assignment,
      computedStatus: latenessFromString(statusStr),
      mySubmission: mySub,
    );
  }

  Map<String, dynamic> toJson() => {
    'assignment': assignment.toJson(),
    'computed_status': latenessToString(computedStatus),
    'my_submission': mySubmission?.toJson(),
  };
}

/// แถวข้อมูลการส่งของนักเรียน (สำหรับรายการในหน้าครู)
class TeacherSubmissionRow {
  final String studentId;
  final String? contentUrl;
  final bool graded;
  final int? score;
  final SubmissionLateness submissionStatus;
  final DateTime? submittedAt;

  TeacherSubmissionRow({
    required this.studentId,
    required this.contentUrl,
    required this.graded,
    required this.score,
    required this.submissionStatus,
    required this.submittedAt,
  });

  factory TeacherSubmissionRow.fromJson(Map<String, dynamic> j) {
    DateTime? _parseDt(dynamic s) =>
        s == null ? null : DateTime.tryParse(s.toString())?.toLocal();

    return TeacherSubmissionRow(
      studentId: j['student_id']?.toString() ?? '',
      contentUrl: j['content_url']?.toString(),
      graded: j['graded'] == true,
      score: (j['score'] is num)
          ? (j['score'] as num).toInt()
          : (j['score'] as int?),
      submissionStatus: latenessFromString(j['submission_status']?.toString()),
      submittedAt: _parseDt(j['submitted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'content_url': contentUrl,
    'graded': graded,
    'score': score,
    'submission_status': latenessToString(submissionStatus),
    'submitted_at': submittedAt?.toUtc().toIso8601String(),
  };
}

/// ===============================
/// Teacher detailed view model
/// ===============================

/// โมเดลสำหรับ “หน้าครูดู/ให้คะแนนรายคน”
/// (ยืดหยุ่น: เผื่อ backend ส่งชื่อ/อีเมล/URL ที่ต่างคีย์กัน)
class StudentSubmission {
  final String submissionId;
  final String assignmentId;
  final String studentId;

  /// อาจมาจาก backend ที่ชื่อไม่เหมือนกัน: student_name หรือ name
  final String? studentName;

  /// URL ไฟล์ PDF ที่ส่ง (content_url / file_url)
  final String? fileUrl;

  final DateTime? submittedAt;
  final bool graded;
  final int? score;
  final SubmissionLateness submissionStatus;

  StudentSubmission({
    required this.submissionId,
    required this.assignmentId,
    required this.studentId,
    required this.submissionStatus,
    this.studentName,
    this.fileUrl,
    this.submittedAt,
    this.graded = false,
    this.score,
  });

  factory StudentSubmission.fromJson(Map<String, dynamic> j) {
    final subId = (j['submission_id'] ?? j['id'] ?? '').toString();
    final asgId = (j['assignment_id'] ?? '').toString();
    final stuId = (j['student_id'] ?? '').toString();
    final statRaw = (j['submission_status'] ?? 'Not_Submitted').toString();
    final status = latenessFromString(statRaw);

    DateTime? submitted;
    final subAt = j['submitted_at']?.toString();
    if (subAt != null && subAt.isNotEmpty) {
      submitted = DateTime.tryParse(subAt)?.toLocal();
    }

    return StudentSubmission(
      submissionId: subId,
      assignmentId: asgId,
      studentId: stuId,
      studentName: j['student_name']?.toString() ?? j['name']?.toString(),
      fileUrl: j['content_url']?.toString() ?? j['file_url']?.toString(),
      submittedAt: submitted,
      graded: j['graded'] == true,
      score: (j['score'] is num)
          ? (j['score'] as num).toInt()
          : int.tryParse('${j['score']}'),
      submissionStatus: status,
    );
  }

  Map<String, dynamic> toJson() => {
    'submission_id': submissionId,
    'assignment_id': assignmentId,
    'student_id': studentId,
    'student_name': studentName,
    'content_url': fileUrl,
    'submitted_at': submittedAt?.toUtc().toIso8601String(),
    'graded': graded,
    'score': score,
    'submission_status': latenessToString(submissionStatus),
  };
}

/// ===============================
/// Utilities
/// ===============================

/// Helper: decode list<T> จาก JSON array
List<T> decodeList<T>(String body, T Function(Map<String, dynamic>) factory) {
  final raw = json.decode(body) as List;
  return raw.map((e) => factory(e as Map<String, dynamic>)).toList();
}
