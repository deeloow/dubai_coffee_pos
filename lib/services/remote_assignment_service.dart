import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';

class RemoteAssignmentService {
  // Local-backed stub using Hive `assignments` box.
  final Future<Box> _assignmentsBoxFuture;

  RemoteAssignmentService() : _assignmentsBoxFuture = Hive.openBox('assignments');

  Future<List<Assignment>> fetchAssignmentsForDate(DateTime date) async {
    final assignmentsBox = await _assignmentsBoxFuture;
    final start = DateTime(date.year, date.month, date.day);
    return assignmentsBox.values
        .cast<Map>()
        .map((m) => Assignment.fromMap(Map<String, dynamic>.from(m)))
        .where((a) => a.date.year == start.year && a.date.month == start.month && a.date.day == start.day)
        .toList();
  }

  Future<void> upsertAssignment(Assignment assignment) async {
    final assignmentsBox = await _assignmentsBoxFuture;
    await assignmentsBox.put(assignment.id, assignment.toMap());
  }
}
