import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPass = false;
  UserRole _role = UserRole.barista;
  String? _statusMessage;
  bool _statusIsError = false;

  // Email validation regex - RFC 5322 simplified pattern
  static final _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
  );

  bool _isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    return _emailRegex.hasMatch(email.trim());
  }

  String? _validateName(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Name is required.';
    return null;
  }

  String? _validateEmail(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Email is required.';
    if (!_isValidEmail(trimmed)) return 'Please enter a valid email address.';
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Password is required.';
    if ((value ?? '').length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Please confirm your password.';
    if (value != _passCtrl.text) return 'Passwords do not match.';
    return null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (kDebugMode) print('🔍 Create Account button clicked');
    setState(() {
      _statusMessage = null;
      _statusIsError = false;
    });

    if (!_formKey.currentState!.validate()) {
      if (kDebugMode) print('❌ Form validation failed');
      setState(() {
        _statusMessage = 'Please fix the highlighted fields and try again.';
        _statusIsError = true;
      });
      return;
    }

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final name = _nameCtrl.text.trim();
    if (kDebugMode) print('📝 Form data: name=$name, email=$email');

    if (password != _confirmCtrl.text) {
      if (kDebugMode) print('❌ Passwords do not match');
      setState(() {
        _statusMessage = 'Passwords do not match.';
        _statusIsError = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }

    final auth = context.read<AuthProvider>();
    try {
      if (kDebugMode) print('🔄 Calling auth.register()...');
      final ok = await auth.register(email, password, name, _role);
      if (kDebugMode) print('✅ auth.register() returned: $ok');

      if (!mounted) return;

      if (ok) {
        if (kDebugMode) print('✅ Account created successfully!');
        _passCtrl.clear();
        _confirmCtrl.clear();
        setState(() {
          _statusMessage = 'Account created successfully. Please sign in.';
          _statusIsError = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully. Please sign in.'),
              backgroundColor: AppColors.green,
              duration: Duration(seconds: 2),
            ),
          );

          await Future.delayed(const Duration(milliseconds: 250));

          if (!mounted) return;
          Navigator.of(context).pop();
        }
        return;
      }

      final message = auth.error ?? 'We couldn\'t create your account. Please try again.';
      if (kDebugMode) print('❌ Registration failed: $message');
      setState(() {
        _statusMessage = message;
        _statusIsError = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      const message = 'Unable to create your account right now. Please try again later.';
      if (kDebugMode) {
        debugPrint('❌ Unhandled register exception: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      setState(() {
        _statusMessage = message;
        _statusIsError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to create your account right now. Please try again later.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Widget _buildCreateAccountButton(AuthProvider auth) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.espresso,
          foregroundColor: AppColors.goldLight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: auth.loading
            ? null
            : () {
                if (kDebugMode) {
                  print('[CREATE_ACCOUNT] BUTTON CLICKED');
                }
                _submit();
              },
        child: auth.loading
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldLight))),
                  SizedBox(width: 8),
                  Text('Creating Account...'),
                ],
              )
            : const Text('Create Account'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.espresso,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppColors.espresso,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isLandscape ? 16 : 24,
                isLandscape ? 16 : 24,
                isLandscape ? 16 : 24,
                (isLandscape ? 16 : 24) + bottomInset,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: isLandscape
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset('assets/icon.png', width: 84, height: 84),
                                    const SizedBox(height: 8),
                                    Text('Dubai Coffee', style: GoogleFonts.dmSans(color: AppColors.goldLight, fontSize: 22, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 8),
                                    const AppText('New staff account', size: 14, weight: FontWeight.w600),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(16)),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: AppTextField(label: 'Full Name', controller: _nameCtrl, prefix: const Icon(Icons.person_outline, size: 18, color: AppColors.textMuted), validator: _validateName)),
                                          const SizedBox(width: 10),
                                          Expanded(child: AppTextField(label: 'Email', controller: _emailCtrl, keyboardType: TextInputType.emailAddress, prefix: const Icon(Icons.email_outlined, size: 18, color: AppColors.textMuted), validator: _validateEmail)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(child: AppTextField(label: 'Password', controller: _passCtrl, obscure: !_showPass, prefix: const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted), suffix: IconButton(icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted), onPressed: () => setState(() => _showPass = !_showPass)), validator: _validatePassword)),
                                          const SizedBox(width: 10),
                                          Expanded(child: AppTextField(label: 'Confirm Password', controller: _confirmCtrl, obscure: !_showPass, prefix: const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted), validator: _validateConfirmPassword)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: AppColors.bgLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.borderColor, width: 0.5)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const AppText('Role', size: 12, color: AppColors.textMuted),
                                            const SizedBox(height: 8),
                                            Wrap(spacing: 10, runSpacing: 8, children: [
                                              _roleChip(UserRole.barista, 'Barista', Icons.coffee_outlined),
                                              _roleChip(UserRole.admin, 'Admin', Icons.admin_panel_settings_outlined),
                                            ]),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (_statusMessage != null)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _statusIsError ? AppColors.red.withValues(alpha: 0.12) : AppColors.green.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _statusIsError ? AppColors.red : AppColors.green,
                                              width: 1,
                                            ),
                                          ),
                                          child: AppText(
                                            _statusMessage!,
                                            size: 12,
                                            color: _statusIsError ? AppColors.red : AppColors.green,
                                          ),
                                        ),
                                      if (_statusMessage != null && !_statusIsError)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.green.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.green, width: 1),
                                          ),
                                          child: const AppText(
                                            'Account created successfully',
                                            size: 12,
                                            color: AppColors.green,
                                          ),
                                        ),
                                      _buildCreateAccountButton(auth),
                                      const SizedBox(height: 10),
                                      GestureDetector(onTap: () => Navigator.pop(context), child: const AppText('Already have an account? Sign in', size: 12, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Image.asset('assets/icon.png', width: 66, height: 66),
                              const SizedBox(height: 8),
                              Text('Dubai Coffee', style: GoogleFonts.dmSans(color: AppColors.goldLight, fontSize: 20, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const AppText('New staff account', size: 15, weight: FontWeight.w600),
                                    const SizedBox(height: 16),
                                    AppTextField(label: 'Full Name', controller: _nameCtrl, prefix: const Icon(Icons.person_outline, size: 18, color: AppColors.textMuted), validator: _validateName),
                                    const SizedBox(height: 12),
                                    AppTextField(label: 'Email', controller: _emailCtrl, keyboardType: TextInputType.emailAddress, prefix: const Icon(Icons.email_outlined, size: 18, color: AppColors.textMuted), validator: _validateEmail),
                                    const SizedBox(height: 12),
                                    AppTextField(label: 'Password', controller: _passCtrl, obscure: !_showPass, prefix: const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted), suffix: IconButton(icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted), onPressed: () => setState(() => _showPass = !_showPass)), validator: _validatePassword),
                                    const SizedBox(height: 12),
                                    AppTextField(label: 'Confirm Password', controller: _confirmCtrl, obscure: !_showPass, prefix: const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted), validator: _validateConfirmPassword),
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.bgLight,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.borderColor, width: 0.5),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const AppText('Role', size: 12, color: AppColors.textMuted),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 8,
                                            children: [
                                              _roleChip(UserRole.barista, 'Barista', Icons.coffee_outlined),
                                              _roleChip(UserRole.admin, 'Admin', Icons.admin_panel_settings_outlined),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    if (_statusMessage != null)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _statusIsError ? AppColors.red.withValues(alpha: 0.12) : AppColors.green.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _statusIsError ? AppColors.red : AppColors.green,
                                            width: 1,
                                          ),
                                        ),
                                        child: AppText(
                                          _statusMessage!,
                                          size: 12,
                                          color: _statusIsError ? AppColors.red : AppColors.green,
                                        ),
                                      ),
                                    if (_statusMessage != null && !_statusIsError)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.green.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.green, width: 1),
                                        ),
                                        child: const AppText(
                                          'Account created successfully',
                                          size: 12,
                                          color: AppColors.green,
                                        ),
                                      ),
                                    _buildCreateAccountButton(auth),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(onTap: () => Navigator.pop(context), child: const AppText('Already have an account? Sign in', size: 13, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            if (auth.loading) const LoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(UserRole role, String label, IconData icon) {
    final selected = _role == role;
    return GestureDetector(
      onTap: () => setState(() => _role = role),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.espresso : AppColors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color:
                  selected ? AppColors.espresso : AppColors.borderColor,
              width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? AppColors.goldLight
                    : AppColors.textMuted),
            const SizedBox(width: 6),
            AppText(label,
                size: 12,
                weight: FontWeight.w500,
                color: selected
                    ? AppColors.goldLight
                    : AppColors.espresso),
          ],
        ),
      ),
    );
  }
}
