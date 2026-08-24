import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'remote_assignment_service.dart';

class AssignmentService {
  final RemoteAssignmentService _remoteService = RemoteAssignmentService();
  final Future<Box> _assignmentsBoxFuture;
  final Uuid _uuid = const Uuid();

  AssignmentService() : _assignmentsBoxFuture = Hive.openBox('assignments');

  Stream<List<Assignment>> assignmentsStream() async* {
    final assignmentsBox = await _assignmentsBoxFuture;
    yield assignmentsBox.values
        .cast<Map>()
        .map((item) => Assignment.fromMap(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await for (final _ in assignmentsBox.watch()) {
      yield assignmentsBox.values
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
    final assignmentsBox = await _assignmentsBoxFuture;
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
    await assignmentsBox.put(id, assignment.toMap());
    await syncAssignmentRemotely(assignment);
  }

  Future<void> recordLoginAssignment(AppUser barista) async {
    final assignmentsBox = await _assignmentsBoxFuture;
    final today = DateTime.now();
    final alreadyRecorded = assignmentsBox.values.cast<Map>().map(
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

    await assignmentsBox.put(newAssignment.id, newAssignment.toMap());
    await syncAssignmentRemotely(newAssignment);
  }

  Future<Assignment?> getTodayLoginAssignmentForUser(String baristaId) async {
    final assignmentsBox = await _assignmentsBoxFuture;
    final today = DateTime.now();
    for (final item in assignmentsBox.values.cast<Map>()) {
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
    final assignmentsBox = await _assignmentsBoxFuture;
    return assignmentsBox.values
        .cast<Map>()
        .map((item) => Assignment.fromMap(Map<String, dynamic>.from(item)))
        .where((assignment) => assignment.date.year == date.year && assignment.date.month == date.month && assignment.date.day == date.day)
        .toList();
  }

  Future<void> syncAssignmentRemotely(Assignment assignment) async {
    final assignmentsBox = await _assignmentsBoxFuture;
    try {
      await _remoteService.upsertAssignment(assignment);
      await assignmentsBox.put(
        assignment.id,
        assignment.copyWith(synced: true).toMap(),
      );
    } catch (_) {
      // Ignore remote failures to keep offline functionality intact.
    }
  }

  Future<int> mergeRemoteAssignments(List<Assignment> remoteAssignments) async {
    final assignmentsBox = await _assignmentsBoxFuture;
    var count = 0;
    for (final assignment in remoteAssignments) {
      final exists = assignmentsBox.containsKey(assignment.id);
      await assignmentsBox.put(assignment.id, assignment.copyWith(synced: true).toMap());
      if (!exists) count++;
    }
    return count;
  }
}
