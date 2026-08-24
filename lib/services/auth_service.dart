import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class AuthService {
  final Future<Box> _usersBoxFuture;
  final Future<Box> _sessionBoxFuture;
  final Uuid _uuid = const Uuid();

  AuthService()
      : _usersBoxFuture = Hive.openBox('users'),
        _sessionBoxFuture = Hive.openBox('session');

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
    if (kDebugMode) print('🔍 [AuthService.register] Starting registration for: $email');
    final usersBox = await _usersBoxFuture;
    try {
      final trimmedEmail = email.trim();
      final trimmedName = name.trim();
      final emailPattern = RegExp(
        r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
      );

      if (trimmedName.isEmpty) {
        throw Exception('name-required');
      }
      if (trimmedEmail.isEmpty || !emailPattern.hasMatch(trimmedEmail)) {
        throw Exception('invalid-email');
      }
      if (password.isEmpty || password.length < 6) {
        throw Exception('weak-password');
      }

      final normalizedEmail = trimmedEmail.toLowerCase();
      if (kDebugMode) print('📍 [AuthService.register] Checking for duplicate email: $normalizedEmail');
      final exists = usersBox.values
          .map((item) => _toMap(item))
          .any((item) => (item['email'] ?? '').toString().trim().toLowerCase() == normalizedEmail);
      if (exists) {
        if (kDebugMode) print('❌ [AuthService.register] Email already registered: $normalizedEmail');
        throw Exception('email-already-in-use');
      }

      if (kDebugMode) print('✅ [AuthService.register] Email is unique, proceeding with registration');
      return await _localRegister(normalizedEmail, password, trimmedName, role);
    } catch (e) {
      if (kDebugMode) print('❌ [AuthService.register] Error: $e');
      rethrow;
    }
  }

  Future<AppUser?> _fetchUser(String uid) async {
    final usersBox = await _usersBoxFuture;
    try {
      final data = usersBox.get(uid);
      if (data == null) return null;
      final map = _toMap(data);
      return AppUser.fromMap(map);
    } catch (e) {
      if (kDebugMode) print('FetchUser error for $uid: $e');
      return null;
    }
  }

  Future<List<AppUser>> getUsersByRole(UserRole role) async {
    final usersBox = await _usersBoxFuture;
    try {
      // Return only local users filtered by role.
      final users = <AppUser>[];
      for (final item in usersBox.values) {
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
    final sessionBox = await _sessionBoxFuture;
    try {
      final userId = sessionBox.get('currentUserId') as String?;
      if (userId == null) return null;
      return await _fetchUser(userId);
    } catch (e) {
      if (kDebugMode) print('GetCurrentUserProfile error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    final sessionBox = await _sessionBoxFuture;
    try {
      await sessionBox.delete('currentUserId');
    } catch (e) {
      if (kDebugMode) print('SignOut error: $e');
      rethrow;
    }
  }

  Future<void> ensureDefaultAdmin() async {
    final usersBox = await _usersBoxFuture;
    try {
      final adminExists = usersBox.values
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
    final usersBox = await _usersBoxFuture;
    try {
      final userMap = user.toMap();
      if (password.isNotEmpty) {
        userMap['password'] = password;
      }
      await usersBox.put(user.id, userMap);
    } catch (e) {
      if (kDebugMode) print('StoreLocalUser error: $e');
      rethrow;
    }
  }

  Future<void> _storeSession(String userId) async {
    final sessionBox = await _sessionBoxFuture;
    try {
      await sessionBox.put('currentUserId', userId);
    } catch (e) {
      if (kDebugMode) print('StoreSession error: $e');
      rethrow;
    }
  }

  Future<AppUser?> _localSignIn(String email, String password) async {
    final usersBox = await _usersBoxFuture;
    final sessionBox = await _sessionBoxFuture;
    try {
      AppUser? matchedUser;
      String? matchedPassword;

      final normalizedEmail = email.trim().toLowerCase();

      for (int i = 0; i < usersBox.length; i++) {
        try {
          final map = _toMap(usersBox.getAt(i));
          final storedEmail = (map['email'] ?? '').toString().trim().toLowerCase();
          if (storedEmail == normalizedEmail) {
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

      await sessionBox.put('currentUserId', matchedUser.id);
      return matchedUser;
    } catch (e) {
      if (kDebugMode) print('LocalSignIn error: $e');
      rethrow;
    }
  }

  Future<AppUser?> _localRegister(
      String email, String password, String name, UserRole role) async {
    if (kDebugMode) print('🔄 [AuthService._localRegister] Creating new user: $email');
    try {
      final id = _uuid.v4();
      if (kDebugMode) print('🏗️ [AuthService._localRegister] Generated user ID: $id');
      final user = AppUser(id: id, name: name, email: email, role: role);
      await _storeLocalUser(user, password);
      await _storeSession(user.id);

      final usersBox = await _usersBoxFuture;
      final saved = usersBox.get(user.id);
      final savedMap = _toMap(saved);
      final savedEmail = (savedMap['email'] ?? '').toString().trim().toLowerCase();
      final savedName = (savedMap['name'] ?? '').toString().trim();

      if (saved == null || savedEmail != email.toLowerCase() || savedName != name.trim()) {
        throw Exception('account-not-saved');
      }

      if (kDebugMode) print('✅ [AuthService._localRegister] User stored successfully and confirmed in Hive');
      return user;
    } catch (e) {
      if (kDebugMode) print('❌ [AuthService._localRegister] Error: $e');
      rethrow;
    }
  }
}
