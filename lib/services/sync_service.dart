import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';

class SyncService {
  final Box _assignments = Hive.box('assignments');

  String exportAssignmentsForDate(DateTime date) {
    final assignments = _assignments.values
        .cast<Map>()
        .map((item) => Assignment.fromMap(Map<String, dynamic>.from(item)))
        .where((assignment) =>
            assignment.date.year == date.year &&
            assignment.date.month == date.month &&
            assignment.date.day == date.day)
        .toList();

    final jsonList = assignments.map((assignment) => assignment.toMap()).toList();
    return jsonEncode(jsonList);
  }

  Future<int> importAssignments(String jsonText) async {
    final raw = jsonDecode(jsonText);
    if (raw is! List) {
      throw Exception('Invalid sync data format. Expected a JSON list of assignments.');
    }

    var imported = 0;
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item.map((key, value) => MapEntry(key.toString(), value)));
      final id = map['id']?.toString();
      if (id == null || id.isEmpty) continue;

      if (!_assignments.containsKey(id)) {
        imported++;
      }
      await _assignments.put(id, map);
    }

    return imported;
  }
}
