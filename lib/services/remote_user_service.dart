import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';

class RemoteUserService {
  // Local-backed remote service stub. Uses the Hive `users` box.
  final Box _users = Hive.box('users');

  Future<AppUser?> fetchUserById(String id) async {
    final map = _users.get(id);
    if (map == null) return null;
    return AppUser.fromMap(Map<String, dynamic>.from(map as Map));
  }

  Future<AppUser?> fetchUserByEmail(String email) async {
    try {
      final matching = _users.values.cast<Map>().firstWhere(
            (m) => (m)['email'] == email,
            orElse: () => {},
          );
      if (matching.isEmpty) return null;
      return AppUser.fromMap(Map<String, dynamic>.from(matching));
    } catch (_) {
      return null;
    }
  }

  Future<List<AppUser>> fetchUsersByRole(UserRole role) async {
    return _users.values
        .cast<Map<String, dynamic>>()
        .map(AppUser.fromMap)
        .where((u) => u.role == role)
        .toList();
  }

  Future<bool> remoteAdminExists() async {
    return _users.values
        .cast<Map<String, dynamic>>()
        .any((item) => item['role'] == 'admin');
  }

  Future<void> insertUserProfile(AppUser user, String userId) async {
    await _users.put(userId, user.toMap());
  }

  Future<void> createAuthUser(AppUser user, String password) async {
    // Create a local user entry to act as auth user in offline mode.
    await _users.put(user.id, {
      ...user.toMap(),
      'password': password,
    });
  }
}
