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
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _authService.register(email, password, name, role);
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
      print('🔴 Auth Error: $raw');
    }
    if (raw.contains('user-not-found')) return 'No account found with this email. Try: admin@dubai.coffee';
    if (raw.contains('wrong-password')) return 'Incorrect password. Try: admin123';
    if (raw.contains('email-already-in-use')) return 'Email already registered.';
    if (raw.contains('weak-password')) return 'Password must be at least 6 characters.';
    if (raw.contains('invalid-email')) return 'Invalid email address.';
    if (raw.contains('network-request-failed')) return 'Network error. Check your connection.';
    if (raw.contains('PERMISSION_DENIED')) return 'Firestore permission error. Check your Firebase rules.';
    return 'Authentication failed: $raw';
  }
}
