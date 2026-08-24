import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/services/menu_service.dart';
import 'package:image/image.dart' as img;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getApplicationSupportDirectory':
            return '/tmp/dubai_coffee_pos_test_support';
          case 'getApplicationDocumentsDirectory':
            return '/tmp/dubai_coffee_pos_test_docs';
          default:
            return null;
        }
      },
    );

    await Hive.initFlutter();
    await Hive.openBox('menu');
    await Hive.openBox('recipes');
    await Hive.openBox('inventory');
  });
  test('MenuItem preserves image metadata when serialized', () {
    final item = MenuItem(
      id: 'menu-1',
      name: 'Matcha',
      price: 50.0,
      icon: '☕',
      category: 'Cloud series',
      imagePath: '/tmp/matcha.png',
      imageBase64: 'aGVsbG8=',
      imageMimeType: 'image/png',
    );

    final map = item.toMap();
    final restored = MenuItem.fromMap(map, id: item.id);

    expect(restored.imagePath, '/tmp/matcha.png');
    expect(restored.imageBase64, 'aGVsbG8=');
    expect(restored.imageMimeType, 'image/png');
  });

  test('MenuService persists uploaded image bytes and returns metadata', () async {
    final service = MenuService();
    final image = img.Image(width: 320, height: 180);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixel(x, y, img.ColorRgb8(20, 120, 200));
      }
    }

    final result = await service.saveMenuImageBytes(img.encodeJpg(image, quality: 85), menuItemId: 'menu-123');

    expect(result, isNotNull);
    expect(result!.path, isNotEmpty);
    expect(result.base64, isNotEmpty);
    expect(result.mimeType, 'image/jpeg');
    expect(await File(result.path).exists(), isTrue);
  });

  test('MenuService also handles PNG uploads', () async {
    final service = MenuService();
    final image = img.Image(width: 240, height: 140);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixel(x, y, img.ColorRgb8(180, 40, 90));
      }
    }

    final result = await service.saveMenuImageBytes(img.encodePng(image), menuItemId: 'menu-png');

    expect(result, isNotNull);
    expect(result!.path, isNotEmpty);
    expect(result.base64, isNotEmpty);
    expect(result.mimeType, 'image/jpeg');
    expect(await File(result.path).exists(), isTrue);
  });

  test('MenuService clears a custom image and preserves the existing menu item id', () async {
    final service = MenuService();
    final item = MenuItem(
      id: 'menu-clear',
      name: 'Test Drink',
      price: 55.0,
      icon: '☕',
      category: 'Coffee-espresso base',
      imagePath: '/tmp/old-image.jpg',
      imageBase64: 'ZmFrZQ==',
      imageMimeType: 'image/jpeg',
    );
    await service.addItem(item);

    final imageFile = File('/tmp/old-image.jpg');
    await imageFile.writeAsBytes([1, 2, 3, 4]);

    await service.clearMenuImage(item.id, previousPath: imageFile.path);

    final updatedItem = service.getMenuItemById(item.id);
    expect(updatedItem, isNotNull);
    expect(updatedItem!.id, item.id);
    expect(updatedItem.imagePath, MenuItem.defaultDrinkImageAsset);
    expect(updatedItem.imageBase64, isNull);
    expect(updatedItem.imageMimeType, isNull);
    expect(await imageFile.exists(), isFalse);
  });

  test('replaceMenuWithStandardSeed restores the built-in default image state', () async {
    final service = MenuService();
    final customImageFile = File('/tmp/reset-image-custom.jpg');
    await customImageFile.writeAsBytes([9, 8, 7, 6]);

    final editedItem = MenuItem(
      id: 'menu-edited',
      name: 'Premium Matcha',
      price: 150.0,
      icon: '☕',
      category: 'Coffee-espresso base',
      imagePath: customImageFile.path,
      imageBase64: 'ZmFrZQ==',
      imageMimeType: 'image/jpeg',
    );
    await service.addItem(editedItem);

    await service.replaceMenuWithStandardSeed();

    final restoredItems = await service.fetchMenuItems();
    final restoredMatcha = restoredItems.where((item) => item.name.contains('Matcha')).toList();

    expect(restoredItems.any((item) => item.name == 'Premium Matcha'), isFalse);
    expect(restoredItems.any((item) => item.name == 'Matcha'), isTrue);
    expect(restoredItems.every((item) => item.imagePath == MenuItem.defaultDrinkImageAsset), isTrue);
    expect(await customImageFile.exists(), isFalse);
  });

  test('legacy size-based coffee menu entries are replaced with the single-item structure', () async {
    final service = MenuService();
    await service.addItem(MenuItem(
      id: 'legacy-1',
      name: 'Flat White 12oz',
      price: 60.0,
      icon: '🤍',
      category: 'Coffee-espresso base',
    ));
    await service.addItem(MenuItem(
      id: 'legacy-2',
      name: 'Flat White 16oz',
      price: 80.0,
      icon: '🤍',
      category: 'Coffee-espresso base',
    ));

    await service.seedMenuIfEmpty();

    final restoredItems = await service.fetchMenuItems();
    final coffeeItems = restoredItems.where((item) => item.category == 'Coffee-espresso base').toList();

    expect(coffeeItems.any((item) => item.name == 'Flat White 12oz'), isFalse);
    expect(coffeeItems.any((item) => item.name == 'Flat White 16oz'), isFalse);
    expect(coffeeItems.any((item) => item.name == 'Flat White'), isTrue);
    expect(coffeeItems.where((item) => item.name.contains('12oz') || item.name.contains('16oz')).length, 0);
  });
}
