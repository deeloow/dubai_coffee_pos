import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/auth_service.dart';
import 'services/auth_provider.dart';
import 'services/local_order_socket_provider.dart';
import 'services/pos_provider.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase removed — app runs fully offline using Hive boxes.

  await Hive.initFlutter();
  await Hive.openBox('users');
  await Hive.openBox('orders');
  await Hive.openBox('inventory');
  await Hive.openBox('menu');
  await Hive.openBox('assignments');
  await Hive.openBox('recipes');
  await Hive.openBox('session');
  // Run default admin setup in background (don't wait for it)
  AuthService().ensureDefaultAdmin();
  runApp(const DubaiCoffeeApp());
}

class DubaiCoffeeApp extends StatelessWidget {
  const DubaiCoffeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => PosProvider()),
        ChangeNotifierProvider(create: (_) => LocalOrderSocketProvider()..init()),
      ],
      child: MaterialApp(
        title: 'Dubai Coffee POS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const _RootRouter(),
      ),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading) {
      return Scaffold(
        backgroundColor: AppColors.espresso,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/icon.png', width: 72, height: 72),
              const SizedBox(height: 16),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
            ],
          ),
        ),
      );
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    return const MainShell();
  }
}
