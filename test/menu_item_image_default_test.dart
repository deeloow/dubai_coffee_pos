import 'package:flutter_test/flutter_test.dart';
import 'package:dubai_coffee_pos/models/models.dart';

void main() {
  test('menu items without a custom image resolve to the app logo asset', () {
    final item = MenuItem(
      id: 'item-1',
      name: 'Test Drink',
      price: 50,
      icon: '☕',
      category: 'Coffee-espresso base',
    );

    expect(item.hasCustomImage, isFalse);
    expect(item.displayImagePath, MenuItem.defaultDrinkImageAsset);
  });

  test('menu items with a custom image keep that image instead of falling back', () {
    final item = MenuItem(
      id: 'item-2',
      name: 'Test Drink',
      price: 50,
      icon: '☕',
      category: 'Coffee-espresso base',
      imagePath: '/tmp/custom-drink.jpg',
    );

    expect(item.hasCustomImage, isTrue);
    expect(item.displayImagePath, '/tmp/custom-drink.jpg');
  });
}
