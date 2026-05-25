import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'remote_assignment_service.dart';

class AssignmentService {
  final RemoteAssignmentService _remoteService = RemoteAssignmentService();
  final Box _assignments = Hive.box('assignments');
  final Uuid _uuid = const Uuid();

  Stream<List<Assignment>> assignmentsStream() async* {
    yield _assignments.values
        .cast<Map>()
        .map((item) => Assignment.fromMap(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await for (final _ in _assignments.watch()) {
      yield _assignments.values
          .cast<Map>()
          .map((item) => Assignment.fromMap(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  Future<void> addAssignment({
    required String baristaId,
    required String baristaName,
    required String assignedBy,
    required String shift,
    String type = 'manual',
  }) async {
    final id = _uuid.v4();
    final assignment = Assignment(
      id: id,
      baristaId: baristaId,
      baristaName: baristaName,
      assignedBy: assignedBy,
      shift: shift,
      type: type,
      date: DateTime.now(),
      createdAt: DateTime.now(),
      synced: false,
    );
    await _assignments.put(id, assignment.toMap());
    await syncAssignmentRemotely(assignment);
  }

  Future<void> recordLoginAssignment(AppUser barista) async {
    final today = DateTime.now();
    final alreadyRecorded = _assignments.values.cast<Map>().map(
          (item) => Assignment.fromMap(Map<String, dynamic>.from(item)),
        ).any((assignment) =>
            assignment.baristaId == barista.id &&
            assignment.type == 'login' &&
            assignment.date.year == today.year &&
            assignment.date.month == today.month &&
            assignment.date.day == today.day);

    if (alreadyRecorded) return;

    final newAssignment = Assignment(
      id: _uuid.v4(),
      baristaId: barista.id,
      baristaName: barista.name,
      assignedBy: barista.name,
      shift: 'Login',
      type: 'login',
      date: DateTime.now(),
      createdAt: DateTime.now(),
      synced: false,
    );

    await _assignments.put(newAssignment.id, newAssignment.toMap());
    await syncAssignmentRemotely(newAssignment);
  }

  Future<Assignment?> getTodayLoginAssignmentForUser(String baristaId) async {
    final today = DateTime.now();
    for (final item in _assignments.values.cast<Map>()) {
      final assignment = Assignment.fromMap(Map<String, dynamic>.from(item));
      if (assignment.baristaId == baristaId &&
          assignment.type == 'login' &&
          assignment.date.year == today.year &&
          assignment.date.month == today.month &&
          assignment.date.day == today.day) {
        return assignment;
      }
    }
    return null;
  }

  Future<List<Assignment>> getAssignmentsForDate(DateTime date) async {
    return _assignments.values
        .cast<Map>()
        .map((item) => Assignment.fromMap(Map<String, dynamic>.from(item)))
        .where((assignment) => assignment.date.year == date.year && assignment.date.month == date.month && assignment.date.day == date.day)
        .toList();
  }

  Future<void> syncAssignmentRemotely(Assignment assignment) async {
    try {
      await _remoteService.upsertAssignment(assignment);
      await _assignments.put(
        assignment.id,
        assignment.copyWith(synced: true).toMap(),
      );
    } catch (_) {
      // Ignore remote failures to keep offline functionality intact.
    }
  }

  Future<int> mergeRemoteAssignments(List<Assignment> remoteAssignments) async {
    var count = 0;
    for (final assignment in remoteAssignments) {
      final exists = _assignments.containsKey(assignment.id);
      await _assignments.put(assignment.id, assignment.copyWith(synced: true).toMap());
      if (!exists) count++;
    }
    return count;
  }
}
