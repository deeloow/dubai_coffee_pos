import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_test/hive_test.dart';
import 'package:dubai_coffee_pos/services/inventory_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpTestHive();
    await Hive.openBox('inventory');
  });

  tearDownAll(() async {
    await Hive.box('inventory').clear();
    await Hive.box('inventory').close();
    await tearDownTestHive();
  });

  testWidgets('inventory seed works in widget test', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await InventoryService().seedInventoryIfEmpty();
    });
    final box = Hive.box('inventory');
    expect(box.length, greaterThan(0));
  });
}
