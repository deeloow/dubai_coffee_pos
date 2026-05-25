import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';

class RemoteAssignmentService {
  // Local-backed stub using Hive `assignments` box.
  final Box _assignments = Hive.box('assignments');

  Future<List<Assignment>> fetchAssignmentsForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    return _assignments.values
        .cast<Map>()
        .map((m) => Assignment.fromMap(Map<String, dynamic>.from(m)))
        .where((a) => a.date.year == start.year && a.date.month == start.month && a.date.day == start.day)
        .toList();
  }

  Future<void> upsertAssignment(Assignment assignment) async {
    await _assignments.put(assignment.id, assignment.toMap());
  }
}
