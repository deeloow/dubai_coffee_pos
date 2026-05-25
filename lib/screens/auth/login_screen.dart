import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.signIn(_emailCtrl.text.trim(), _passCtrl.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Login failed'),
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
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),

                    // Logo
                    Column(
                      children: [
                        Image.asset('assets/icon.png', width: 80, height: 80),
                        const SizedBox(height: 12),
                        Text('Dubai Coffee',
                            style: GoogleFonts.dmSans(
                              color: AppColors.goldLight,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            )),
                        const SizedBox(height: 6),
                        const AppText('POS System',
                            size: 14,
                            color: AppColors.textMuted),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AppText('Sign in to your account',
                              size: 16,
                              weight: FontWeight.w600),
                          const SizedBox(height: 20),

                          AppTextField(
                            label: 'Email',
                            hint: 'your@email.com',
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            prefix: const Icon(Icons.email_outlined,
                                size: 18, color: AppColors.textMuted),
                            validator: (v) =>
                                v == null || !v.contains('@')
                                    ? 'Enter a valid email'
                                    : null,
                          ),

                          const SizedBox(height: 14),

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
                                    ? 'Minimum 6 characters'
                                    : null,
                          ),

                          const SizedBox(height: 20),

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
                                                AppColors.goldLight),
                                      ),
                                    )
                                  : const Text('Sign In'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                auth.loginStatus == 'online'
                                    ? Icons.cloud_done_outlined
                                    : Icons.cloud_off_outlined,
                                size: 18,
                                color: auth.loginStatus == 'online'
                                    ? AppColors.green
                                    : AppColors.red,
                              ),
                              const SizedBox(width: 8),
                              AppText(
                                auth.loginStatus == 'online'
                                    ? 'Using online auth'
                                    : 'Offline auth mode',
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppText("Don't have an account? ",
                            size: 13, color: AppColors.textMuted),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          ),
                          child: const AppText('Sign Up',
                              size: 13,
                              weight: FontWeight.w600,
                              color: AppColors.goldLight),
                        ),
                      ],
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
}
