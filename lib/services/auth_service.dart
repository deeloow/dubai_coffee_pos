import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class AuthService {
  final Box _users = Hive.box('users');
  final Box _session = Hive.box('session');
  final Uuid _uuid = const Uuid();

  String loginMode = 'offline';

  // Helper: Safely convert any value to Map<String, dynamic>
  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  Future<AppUser?> signIn(String email, String password) async {
    // Fully local sign-in. Only Hive-stored users are considered.
    return await _localSignIn(email, password);
  }

  Future<AppUser?> register(
      String email, String password, String name, UserRole role) async {
    try {
      final exists = _users.values
          .map((item) => _toMap(item))
          .any((item) => item['email'] == email);
      if (exists) {
        throw Exception('email-already-in-use');
      }

      return await _localRegister(email, password, name, role);
    } catch (e) {
      if (kDebugMode) print('Register error: $e');
      rethrow;
    }
  }

  Future<AppUser?> _fetchUser(String uid) async {
    try {
      final data = _users.get(uid);
      if (data == null) return null;
      final map = _toMap(data);
      return AppUser.fromMap(map);
    } catch (e) {
      if (kDebugMode) print('FetchUser error for $uid: $e');
      return null;
    }
  }

  Future<List<AppUser>> getUsersByRole(UserRole role) async {
    try {
      // Return only local users filtered by role.
      final users = <AppUser>[];
      for (final item in _users.values) {
        final map = _toMap(item);
        try {
          final user = AppUser.fromMap(map);
          if (user.role == role) {
            users.add(user);
          }
        } catch (e) {
          if (kDebugMode) print('Parse user error: $e');
          continue;
        }
      }
      return users;
    } catch (e) {
      if (kDebugMode) print('GetUsersByRole error: $e');
      return [];
    }
  }

  Future<AppUser?> getCurrentUserProfile() async {
    try {
      final userId = _session.get('currentUserId') as String?;
      if (userId == null) return null;
      return await _fetchUser(userId);
    } catch (e) {
      if (kDebugMode) print('GetCurrentUserProfile error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _session.delete('currentUserId');
    } catch (e) {
      if (kDebugMode) print('SignOut error: $e');
      rethrow;
    }
  }

  Future<void> ensureDefaultAdmin() async {
    try {
      final adminExists = _users.values
          .map((item) => _toMap(item))
          .any((item) => item['role'] == 'admin');

      if (!adminExists) {
        final id = _uuid.v4();
        final admin = AppUser(
          id: id,
          name: 'Admin',
          email: 'admin@dubai.coffee',
          role: UserRole.admin,
        );
        await _storeLocalUser(admin, 'admin123');
      }
    } catch (e) {
      if (kDebugMode) print('EnsureDefaultAdmin error: $e');
      rethrow;
    }
  }

  Future<void> _storeLocalUser(AppUser user, String password) async {
    try {
      final userMap = user.toMap();
      if (password.isNotEmpty) {
        userMap['password'] = password;
      }
      await _users.put(user.id, userMap);
    } catch (e) {
      if (kDebugMode) print('StoreLocalUser error: $e');
      rethrow;
    }
  }

  Future<AppUser?> _localSignIn(String email, String password) async {
    try {
      AppUser? matchedUser;
      String? matchedPassword;

      for (int i = 0; i < _users.length; i++) {
        try {
          final map = _toMap(_users.getAt(i));
          if (map['email'] == email) {
            final storedPassword = map['password'] as String?;
            if (storedPassword == password) {
              matchedUser = AppUser.fromMap(map);
              matchedPassword = storedPassword;
              break;
            }
          }
        } catch (e) {
          if (kDebugMode) print('Parse entry error: $e');
          continue;
        }
      }

      if (matchedUser == null || matchedPassword == null) {
        throw Exception('user-not-found');
      }

      await _session.put('currentUserId', matchedUser.id);
      return matchedUser;
    } catch (e) {
      if (kDebugMode) print('LocalSignIn error: $e');
      rethrow;
    }
  }

  Future<AppUser?> _localRegister(
      String email, String password, String name, UserRole role) async {
    try {
      final id = _uuid.v4();
      final user = AppUser(id: id, name: name, email: email, role: role);
      await _storeLocalUser(user, password);
      await _session.put('currentUserId', id);
      return user;
    } catch (e) {
      if (kDebugMode) print('LocalRegister error: $e');
      rethrow;
    }
  }
}
