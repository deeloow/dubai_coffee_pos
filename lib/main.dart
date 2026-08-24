import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/auth_service.dart';
import 'services/auth_provider.dart';
import 'services/inventory_service.dart';
import 'services/local_order_socket_provider.dart';
import 'services/order_service.dart';
import 'services/pos_provider.dart';
import 'theme/app_theme.dart';
import 'core/responsive.dart';
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
  await Hive.openBox('menu_categories');
  await Hive.openBox('assignments');
  await Hive.openBox('recipes');
  await Hive.openBox('session');
  await Hive.openBox('settings');
  await Hive.openBox('reports_history');

  await InventoryService().seedInventoryIfEmpty();

  // Run default admin setup in background (don't wait for it)
  AuthService().ensureDefaultAdmin();
  OrderService.startDailyArchiveScheduler();
  runApp(const DubaiCoffeeApp());
}

class DubaiCoffeeApp extends StatefulWidget {
  const DubaiCoffeeApp({super.key});

  @override
  State<DubaiCoffeeApp> createState() => _DubaiCoffeeAppState();
}

class _DubaiCoffeeAppState extends State<DubaiCoffeeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      final provider = context.read<LocalOrderSocketProvider>();
      provider.resumeConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => PosProvider()),
        ChangeNotifierProvider(create: (_) => LocalOrderSocketProvider()..init()),
      ],
      child: Builder(
        builder: (context) {
          final responsive = ResponsiveLayout.of(context);
          return MaterialApp(
            title: 'Dubai Coffee POS',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme.copyWith(
              visualDensity: VisualDensity.compact,
              textTheme: AppTheme.theme.textTheme.apply(
                fontSizeFactor: responsive.scale,
              ),
            ),
            home: const _RootRouter(),
          );
        },
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
