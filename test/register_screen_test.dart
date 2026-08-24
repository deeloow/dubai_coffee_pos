import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_test/hive_test.dart';
import 'package:provider/provider.dart';

import 'package:dubai_coffee_pos/screens/auth/register_screen.dart';
import 'package:dubai_coffee_pos/services/auth_provider.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpTestHive();
    await Hive.openBox('users');
    await Hive.openBox('session');
  });

  tearDownAll(() async {
    await tearDownTestHive();
  });

  testWidgets('empty create account form shows validation errors', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required.'), findsOneWidget);
    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.text('Please confirm your password.'), findsOneWidget);
  });

  testWidgets('valid create account form creates and persists a user', (tester) async {
    final auth = AuthProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
    await tester.enterText(find.byType(TextFormField).at(1), 'new-user@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');
    await tester.enterText(find.byType(TextFormField).at(3), 'Password123!');

    final button = find.widgetWithText(ElevatedButton, 'Create Account');
    await tester.tap(button);
    await tester.pump();

    expect(auth.error, isNull);
    final usersBox = Hive.box('users');
    expect(usersBox.values.any((item) => (item as Map)['email'] == 'new-user@example.com'), isTrue);
  });

  testWidgets('portrait layout still creates a user when the button is tapped', (tester) async {
    final auth = AuthProvider();
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Portrait User');
    await tester.enterText(find.byType(TextFormField).at(1), 'portrait-user@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');
    await tester.enterText(find.byType(TextFormField).at(3), 'Password123!');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(auth.error, isNull);
    final usersBox = Hive.box('users');
    expect(usersBox.values.any((item) => (item as Map)['email'] == 'portrait-user@example.com'), isTrue);
  });
}
