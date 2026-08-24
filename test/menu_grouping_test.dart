import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/screens/menu/menu_screen.dart';

void main() {
  testWidgets('MenuScreen groups items by category', (WidgetTester tester) async {
    final controller = StreamController<List<MenuItem>>.broadcast();

    final items = [
      MenuItem(
        id: '1',
        name: 'Americano',
        price: 50.0,
        icon: '☕',
        category: 'Coffee-espresso base',
      ),
      MenuItem(
        id: '2',
        name: 'Cappuccino',
        price: 60.0,
        icon: '☕',
        category: 'Coffee-espresso base',
      ),
      MenuItem(
        id: '3',
        name: 'Strawberry Cloud',
        price: 55.0,
        icon: '🍓',
        category: 'Cloud series',
      ),
      MenuItem(
        id: '4',
        name: 'Green Apple',
        price: 50.0,
        icon: '🍏',
        category: 'Soda base',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuScreen(menuStream: controller.stream, isAdminOverride: false),
        ),
      ),
    );

    controller.add(items);
    await tester.pumpAndSettle();

    expect(find.text('Coffee-espresso base'), findsWidgets);
    expect(find.text('Cloud series'), findsWidgets);
    expect(find.text('Soda base'), findsWidgets);

    expect(find.text('Americano'), findsOneWidget);
    expect(find.text('Strawberry Cloud'), findsOneWidget);

    await controller.close();
  });
}
