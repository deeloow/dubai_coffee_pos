import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/services/menu_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('menu_pricing_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('menu');
  });

  tearDown(() async {
    final box = Hive.box('menu');
    await box.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('uses stored 12oz and 16oz pricing for coffee-base items', () {
    final service = MenuService();
    final item = MenuItem(
      id: '',
      name: 'Flat White',
      price: 60,
      icon: '☕',
      category: 'Coffee-espresso base',
      priceByCupSize: {'12oz': 60, '16oz': 85},
    );

    expect(service.priceForCupSize(item, '12oz'), 60);
    expect(service.priceForCupSize(item, '16oz'), 85);
  });

  test('uses 12oz as the menu card preview for coffee-base items', () {
    final service = MenuService();
    final item = MenuItem(
      id: '',
      name: 'Mocha',
      price: 80,
      icon: '☕',
      category: 'Coffee-espresso base',
      priceByCupSize: {'12oz': 60, '16oz': 85},
    );

    expect(service.displayPriceForMenuCard(item), 60);
  });

  test('uses stored 16oz pricing for non-coffee categories', () {
    final service = MenuService();
    final item = MenuItem(
      id: '',
      name: 'Lemonade',
      price: 10,
      icon: '🧃',
      category: 'Lemonade',
      priceByCupSize: {'16oz': 120},
    );

    expect(service.priceForCupSize(item, '16oz'), 120);
  });

  test('uses stored Regular and Medium pricing for snacks and keeps the selected snack size', () {
    final service = MenuService();
    final item = MenuItem(
      id: '',
      name: 'French Fries',
      price: 35,
      icon: '🍟',
      category: 'Snacks',
      cupSize: 'Regular',
      priceByCupSize: {'Regular': 35, 'Medium': 45},
    );

    expect(service.priceForCupSize(item, 'Regular'), 35);
    expect(service.priceForCupSize(item, 'Medium'), 45);
    expect(service.displayPriceForMenuCard(item), 35);
    expect(item.cupSize, 'Regular');
  });
}
