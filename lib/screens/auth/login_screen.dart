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

  // Email validation regex - RFC 5322 simplified pattern
  static final _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
  );

  bool _isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    return _emailRegex.hasMatch(email.trim());
  }

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
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.espresso,
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
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: isLandscape
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset('assets/icon.png', width: 96, height: 96),
                                    const SizedBox(height: 10),
                                    Text('Dubai Coffee',
                                        style: GoogleFonts.dmSans(
                                          color: AppColors.goldLight,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        )),
                                    const SizedBox(height: 4),
                                    const AppText('POS System', size: 13, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppColors.cream,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const AppText('Sign in to your account', size: 15, weight: FontWeight.w600),
                                      const SizedBox(height: 14),
                                      AppTextField(
                                        label: 'Email',
                                        hint: 'your@email.com',
                                        controller: _emailCtrl,
                                        keyboardType: TextInputType.emailAddress,
                                        prefix: const Icon(Icons.email_outlined, size: 18, color: AppColors.textMuted),
                                        validator: (v) => !_isValidEmail(v) ? 'Enter a valid email format' : null,
                                      ),
                                      const SizedBox(height: 10),
                                      AppTextField(
                                        label: 'Password',
                                        controller: _passCtrl,
                                        obscure: !_showPass,
                                        prefix: const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted),
                                        suffix: IconButton(
                                          icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted),
                                          onPressed: () => setState(() => _showPass = !_showPass),
                                        ),
                                        validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 44,
                                        child: ElevatedButton(
                                          onPressed: auth.loading ? null : _submit,
                                          child: auth.loading
                                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldLight)))
                                              : const Text('Sign In'),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(auth.loginStatus == 'online' ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, size: 16, color: auth.loginStatus == 'online' ? AppColors.green : AppColors.red),
                                          const SizedBox(width: 6),
                                          AppText(auth.loginStatus == 'online' ? 'Using online auth' : 'Offline auth mode', size: 11, color: AppColors.textMuted),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const AppText("Don't have an account? ", size: 12, color: AppColors.textMuted),
                                          GestureDetector(
                                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                                            child: const AppText('Sign Up', size: 12, weight: FontWeight.w600, color: AppColors.goldLight),
                                          ),
                                        ],
                                      ),
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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 48),
                              Column(
                                children: [
                                  Image.asset('assets/icon.png', width: 80, height: 80),
                                  const SizedBox(height: 12),
                                  Text('Dubai Coffee', style: GoogleFonts.dmSans(color: AppColors.goldLight, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                                  const SizedBox(height: 6),
                                  const AppText('POS System', size: 14, color: AppColors.textMuted),
                                ],
                              ),
                              const SizedBox(height: 48),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const AppText('Sign in to your account', size: 16, weight: FontWeight.w600),
                                    const SizedBox(height: 20),
                                    AppTextField(label: 'Email', hint: 'your@email.com', controller: _emailCtrl, keyboardType: TextInputType.emailAddress, prefix: const Icon(Icons.email_outlined, size: 18, color: AppColors.textMuted), validator: (v) => !_isValidEmail(v) ? 'Enter a valid email format' : null),
                                    const SizedBox(height: 14),
                                    AppTextField(label: 'Password', controller: _passCtrl, obscure: !_showPass, prefix: const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted), suffix: IconButton(icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted), onPressed: () => setState(() => _showPass = !_showPass)), validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null),
                                    const SizedBox(height: 20),
                                    SizedBox(height: 48, child: ElevatedButton(onPressed: auth.loading ? null : _submit, child: auth.loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldLight))) : const Text('Sign In'))),
                                    const SizedBox(height: 12),
                                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(auth.loginStatus == 'online' ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, size: 18, color: auth.loginStatus == 'online' ? AppColors.green : AppColors.red), const SizedBox(width: 8), AppText(auth.loginStatus == 'online' ? 'Using online auth' : 'Offline auth mode', size: 12, color: AppColors.textMuted)]),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [const AppText("Don't have an account? ", size: 13, color: AppColors.textMuted), GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const AppText('Sign Up', size: 13, weight: FontWeight.w600, color: AppColors.goldLight))]),
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
}
