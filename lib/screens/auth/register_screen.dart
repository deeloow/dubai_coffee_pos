import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
        _emailCtrl.text.trim(), _passCtrl.text, _nameCtrl.text.trim(), _role);
    if (ok && mounted) {
      Navigator.pop(context);
    } else if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Registration failed'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
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
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Image.asset('assets/icon.png', width: 66, height: 66),
                    const SizedBox(height: 8),
                    Text('Dubai Coffee',
                        style: GoogleFonts.dmSans(
                            color: AppColors.goldLight,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AppText('New staff account',
                              size: 15, weight: FontWeight.w600),
                          const SizedBox(height: 16),

                          AppTextField(
                            label: 'Full Name',
                            controller: _nameCtrl,
                            prefix: const Icon(Icons.person_outline,
                                size: 18, color: AppColors.textMuted),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Name required' : null,
                          ),
                          const SizedBox(height: 12),

                          AppTextField(
                            label: 'Email',
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            prefix: const Icon(Icons.email_outlined,
                                size: 18, color: AppColors.textMuted),
                            validator: (v) =>
                                v == null || !v.contains('@')
                                    ? 'Enter valid email'
                                    : null,
                          ),
                          const SizedBox(height: 12),

                          AppTextField(
                            label: 'Password',
                            controller: _passCtrl,
                            obscure: !_showPass,
                            prefix: const Icon(Icons.lock_outline,
                                size: 18, color: AppColors.textMuted),
                            suffix: IconButton(
                              icon: Icon(
                                  _showPass
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: AppColors.textMuted),
                              onPressed: () =>
                                  setState(() => _showPass = !_showPass),
                            ),
                            validator: (v) =>
                                v == null || v.length < 6
                                    ? 'Min 6 characters'
                                    : null,
                          ),
                          const SizedBox(height: 12),

                          AppTextField(
                            label: 'Confirm Password',
                            controller: _confirmCtrl,
                            obscure: !_showPass,
                            prefix: const Icon(Icons.lock_outline,
                                size: 18, color: AppColors.textMuted),
                            validator: (v) =>
                                v != _passCtrl.text
                                    ? 'Passwords do not match'
                                    : null,
                          ),
                          const SizedBox(height: 14),

                          // Role selector
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.bgLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.borderColor, width: 0.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText('Role',
                                    size: 12, color: AppColors.textMuted),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _roleChip(UserRole.barista, 'Barista',
                                        Icons.coffee_outlined),
                                    const SizedBox(width: 10),
                                    _roleChip(UserRole.admin, 'Admin',
                                        Icons.admin_panel_settings_outlined),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: auth.loading ? null : _submit,
                              child: auth.loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  AppColors.goldLight)))
                                  : const Text('Create Account'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const AppText('Already have an account? Sign in',
                          size: 13, color: AppColors.textMuted),
                    ),
                  ],
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
