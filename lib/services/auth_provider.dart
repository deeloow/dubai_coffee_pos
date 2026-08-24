import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'assignment_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final AssignmentService _assignmentService = AssignmentService();

  AppUser? _user;
  bool _loading = false;
  String? _error;

  AppUser? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.role == UserRole.admin;
  String get loginStatus => _authService.loginMode;

  Future<void> init() async {
    _user = await _authService.getCurrentUserProfile();
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _authService.signIn(email, password);
      if (_user != null && _user!.role == UserRole.barista) {
        await _assignmentService.recordLoginAssignment(_user!);
      }
      _loading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _loading = false;
      _error = _parseError(e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
      String email, String password, String name, UserRole role) async {
    if (kDebugMode) print('🔍 [AuthProvider.register] Starting registration: name=$name, email=$email, role=$role');
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _user = null;
      final trimmedName = name.trim();
      final trimmedEmail = email.trim();
      if (kDebugMode) print('📝 [AuthProvider.register] Trimmed data: name=$trimmedName, email=$trimmedEmail');

      if (trimmedName.isEmpty) {
        throw Exception('name-required');
      }
      if (!RegExp(
              r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$")
          .hasMatch(trimmedEmail)) {
        throw Exception('invalid-email');
      }
      if (password.isEmpty || password.length < 6) {
        throw Exception('weak-password');
      }

      if (kDebugMode) print('🔄 [AuthProvider.register] Calling _authService.register()...');
      final createdUser = await _authService.register(trimmedEmail, password, trimmedName, role);
      if (kDebugMode) print('✅ [AuthProvider.register] Created user: ${createdUser?.id}, isNull=${createdUser == null}');
      if (createdUser != null) {
        _user = createdUser;
      }
      _loading = false;
      notifyListeners();
      final success = createdUser != null;
      if (kDebugMode) print('🏁 [AuthProvider.register] Returning: $success');
      return success;
    } catch (e) {
      _loading = false;
      _error = _parseError(e.toString());
      if (kDebugMode) print('❌ [AuthProvider.register] Error: $e, parsed as: $_error');
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _parseError(String raw) {
    if (kDebugMode) {
      debugPrint('🔴 Auth Error: $raw');
    }
    final normalized = raw.toLowerCase();

    if (normalized.contains('name-required')) return 'Name is required.';
    if (normalized.contains('user-not-found')) return 'No account found with this email. Try: admin@dubai.coffee';
    if (normalized.contains('wrong-password')) return 'Incorrect password. Try: admin123';
    if (normalized.contains('email-already-in-use') || normalized.contains('email already registered')) {
      return 'This email is already registered. Please use another email or sign in.';
    }
    if (normalized.contains('weak-password')) return 'Please use a stronger password.';
    if (normalized.contains('invalid-email')) return 'Please enter a valid email address.';
    if (normalized.contains('passwords do not match') || normalized.contains('password mismatch')) {
      return 'Passwords do not match.';
    }
    if (normalized.contains('account-not-saved')) {
      return 'We couldn\'t finish creating your account. Please try again.';
    }
    if (normalized.contains('network-request-failed') || normalized.contains('socketexception') || normalized.contains('failed host lookup')) {
      return 'Unable to create your account. Please check your internet connection and try again.';
    }
    if (normalized.contains('permission_denied') || normalized.contains('permission denied')) {
      return 'Unable to create your account right now. Please try again later.';
    }
    if (normalized.contains('null') || normalized.contains('formatexception')) {
      return 'Unable to create your account right now. Please try again later.';
    }
    return 'We couldn\'t create your account. Please try again.';
  }
}
