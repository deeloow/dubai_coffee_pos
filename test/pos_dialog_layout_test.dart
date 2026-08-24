import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_test/hive_test.dart';
import 'package:provider/provider.dart';

import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/screens/pos/cash_payment_dialog.dart';
import 'package:dubai_coffee_pos/screens/pos/pos_screen.dart';
import 'package:dubai_coffee_pos/services/auth_provider.dart';
import 'package:dubai_coffee_pos/services/local_order_socket_provider.dart';
import 'package:dubai_coffee_pos/services/pos_provider.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpTestHive();
    await Hive.openBox('settings');
    await Hive.openBox('menu');
    await Hive.openBox('recipes');
    await Hive.openBox('inventory');
    await Hive.openBox('orders');
  });

  tearDownAll(() async {
    await tearDownTestHive();
  });

  testWidgets('cash payment dialog shows amount due and tendered field', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final posProvider = PosProvider();
    posProvider.addItemWithCupSize(
      MenuItem(
        id: 'item-1',
        name: 'Coffee',
        price: 100,
        icon: '☕',
        category: 'Coffee-espresso base',
      ),
      '12oz',
      price: 100,
    );
    posProvider.setCustomerName('Test Customer');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => CashPaymentDialog(
                      total: 100,
                      onConfirm: (_, __) async {},
                      onCancel: () {},
                      onClose: () {},
                    ),
                  ),
                  child: const Text('Open Payment'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Cash Payment'), findsOneWidget);
    expect(find.text('Amount due'), findsOneWidget);
    expect(find.text('Cash tendered'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });
}
