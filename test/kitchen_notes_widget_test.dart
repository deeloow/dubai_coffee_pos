import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dubai_coffee_pos/screens/kitchen/kitchen_screen.dart';

void main() {
  testWidgets('shows additional notes once in the kitchen receipt header', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KitchenOrderNotesBlock(
            orderNotes: 'Less Ice\nExtra Napkins',
          ),
        ),
      ),
    );

    expect(find.text('Additional Notes'), findsOneWidget);
    expect(find.text('Less Ice'), findsOneWidget);
    expect(find.text('Extra Napkins'), findsOneWidget);
  });
}
