import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_test/hive_test.dart';
import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/services/auth_provider.dart';
import 'package:dubai_coffee_pos/services/menu_service.dart';
import 'package:dubai_coffee_pos/services/pos_provider.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpTestHive();
    await Hive.openBox('menu');
    await Hive.openBox('menu_categories');
    await Hive.openBox('recipes');
    await Hive.openBox('inventory');
  });

  tearDownAll(() async {
    await tearDownTestHive();
  });

  test('rejects invalid emails before creating an account', () async {
    final auth = AuthProvider();

    final ok = await auth.register(
        'test@', 'password123', 'Test User', UserRole.barista);

    expect(ok, isFalse);
    expect(auth.user, isNull);
    expect(auth.error, 'Please enter a valid email address.');
  });

  test('returns the required stronger-password message for weak passwords',
      () async {
    final auth = AuthProvider();

    final ok = await auth.register(
        'user@example.com', '123', 'Test User', UserRole.barista);

    expect(ok, isFalse);
    expect(auth.user, isNull);
    expect(auth.error, 'Please use a stronger password.');
  });

  test('creates a valid account and signs the user in immediately', () async {
    final auth = AuthProvider();
    final ok = await auth.register(
        'newstaff@example.com', 'password123', 'New Staff', UserRole.barista);

    expect(ok, isTrue);
    expect(auth.user, isNotNull);
    expect(auth.user!.email, 'newstaff@example.com');
    expect(auth.error, isNull);
  });

  test('newly created account can sign in with its credentials', () async {
    final auth = AuthProvider();
    final created = await auth.register('signedin@example.com', 'password123',
        'Signed In User', UserRole.admin);
    final signedIn = await auth.signIn('signedin@example.com', 'password123');

    expect(created, isTrue);
    expect(signedIn, isTrue);
    expect(auth.user, isNotNull);
    expect(auth.user!.email, 'signedin@example.com');
  });

  test(
      'updates the existing snack cart line when its size is changed instead of creating a duplicate',
      () {
    final provider = PosProvider();
    final menuItem = MenuItem(
      id: 'fries',
      name: 'French Fries',
      price: 50,
      icon: '🍟',
      category: 'Snacks',
      cupSize: 'Regular',
      priceByCupSize: {'Regular': 50, 'Medium': 70},
    );

    provider.addItemWithCupSize(menuItem, 'Regular');
    provider.setItemCupSize(0, 'fries', 'Medium', 70);

    final items = provider.items;
    expect(items.length, 1);
    expect(items.single.menuItemId, 'fries');
    expect(items.single.cupSize, 'Medium');
    expect(items.single.price, 70);
    expect(items.single.qty, 1);
  });

  test('updates the existing cart line when the same drink cup size is edited',
      () {
    final provider = PosProvider();
    final menuItem = MenuItem(
      id: 'matcha',
      name: 'Matcha',
      price: 80,
      icon: '🫖',
      category: 'Coffee-espresso base',
      cupSize: '12oz',
    );

    provider.addItem(menuItem);
    provider.setItemCupSize(0, 'matcha', '16oz', 80);

    final items = provider.items;
    expect(items.length, 1);
    expect(items.single.menuItemId, 'matcha');
    expect(items.single.cupSize, '16oz');
    expect(items.single.qty, 1);
  });

  test(
      'keeps separate cart lines when the same drink is intentionally added twice with different cup sizes',
      () {
    final provider = PosProvider();
    final menuItem = MenuItem(
      id: 'matcha',
      name: 'Matcha',
      price: 80,
      icon: '🫖',
      category: 'Coffee-espresso base',
      cupSize: '12oz',
    );

    provider.addItem(menuItem);
    provider.addItem(menuItem.copyWith(cupSize: '16oz'));

    final items = provider.items;
    expect(items.length, 2);
    expect(items[0].cupSize, '12oz');
    expect(items[1].cupSize, '16oz');
    expect(items[0].qty, 1);
    expect(items[1].qty, 1);
  });

  test('increments quantity for repeated items with the same cup size', () {
    final provider = PosProvider();
    final menuItem = MenuItem(
      id: 'matcha',
      name: 'Matcha',
      price: 80,
      icon: '🫖',
      category: 'Coffee-espresso base',
      cupSize: '12oz',
    );

    provider.addItem(menuItem);
    provider.addItem(menuItem);

    final items = provider.items;
    expect(items.length, 1);
    expect(items.single.cupSize, '12oz');
    expect(items.single.qty, 2);
  });

  test('uses Regular and Medium as the default snack sizes, not drink sizes',
      () {
    final provider = PosProvider();
    final menuItem = MenuItem(
      id: 'brownie',
      name: 'Brownie',
      price: 50,
      icon: '🍫',
      category: 'Snacks',
      cupSize: 'Regular',
      priceByCupSize: {'Regular': 50, 'Medium': 70},
    );

    provider.addItem(menuItem);

    final items = provider.items;
    expect(items.length, 1);
    expect(items.single.cupSize, 'Regular');
    expect(items.single.price, 50);
    expect(items.single.sugarLevel, isEmpty);
  });

  test('uses 16oz as the default cup size for non-coffee categories', () {
    final provider = PosProvider();
    final menuItem = MenuItem(
      id: 'cloud-matcha',
      name: 'Matcha',
      price: 80,
      icon: '🫖',
      category: 'Cloud series',
      cupSize: '12oz',
    );

    provider.addItem(menuItem);

    final items = provider.items;
    expect(items.length, 1);
    expect(items.single.cupSize, '16oz');
    expect(items.single.price, 80);
  });

  test('uses the supplied price for the selected cup size', () {
    final provider = PosProvider();
    final menuItem = MenuItem(
      id: 'coffee',
      name: 'Caramel Macchiato',
      price: 60,
      icon: '☕',
      category: 'Coffee-espresso base',
      cupSize: '12oz',
    );

    provider.addItemWithCupSize(menuItem, '16oz', price: 80);

    final items = provider.items;
    expect(items.length, 1);
    expect(items.single.cupSize, '16oz');
    expect(items.single.price, 80);
  });

  test('applies the standard coffee pricing for 12oz and 16oz selections', () {
    final provider = PosProvider();
    final menuItem = MenuItem(
      id: 'coffee-price',
      name: 'Flat White',
      price: 50,
      icon: '🤍',
      category: 'Coffee-espresso base',
      cupSize: '12oz',
    );

    provider.addItemWithCupSize(menuItem, '12oz');
    provider.addItemWithCupSize(menuItem, '16oz');

    final items = provider.items;
    expect(items.length, 2);
    expect(items.where((item) => item.cupSize == '12oz').single.price, 60);
    expect(items.where((item) => item.cupSize == '16oz').single.price, 80);
  });

  test('uses the latest saved menu price for coffee items added to the cart',
      () async {
    final menuService = MenuService();
    final persistedItem = MenuItem(
      id: 'dynamic-coffee-price',
      name: 'Latte',
      price: 75,
      icon: '☕',
      category: 'Coffee-espresso base',
      cupSize: '12oz',
      priceByCupSize: {'12oz': 75, '16oz': 75},
    );
    await menuService.addItem(persistedItem);

    final provider = PosProvider();
    final staleItem = persistedItem.copyWith(price: 60);

    provider.addItemWithCupSize(staleItem, '12oz');

    final items = provider.items;
    expect(items.length, 1);
    expect(items.single.price, 75);
  });

  test(
      'menu service resolves coffee prices to the standard 12oz and 16oz values',
      () {
    final menuService = MenuService();
    final menuItem = MenuItem(
      id: 'coffee-menu-price',
      name: 'Flat White',
      price: 50,
      icon: '🤍',
      category: 'Coffee-espresso base',
      cupSize: '12oz',
    );

    expect(menuService.priceForCupSize(menuItem, '12oz'), 60);
    expect(menuService.priceForCupSize(menuItem, '16oz'), 80);
  });

  test(
      'keeps Snacks as an available category but starts empty and supports dynamic categories',
      () async {
    final menuService = MenuService();
    await menuService.replaceMenuWithStandardSeed();

    final snackItems = (await menuService.fetchMenuItems())
        .where((item) => item.category.toLowerCase() == 'snacks')
        .toList();
    expect(snackItems, isEmpty);

    final categories = await menuService.fetchCategoryNames();
    expect(categories, contains('Snacks'));

    final duplicateErr = await menuService.addCategory(
        'snacks', CategoryCupSizeType.regularAndMedium);
    expect(duplicateErr, 'This category already exists.');

    final createdErr = await menuService.addCategory(
        'Desserts', CategoryCupSizeType.regularAndMedium);
    expect(createdErr, isNull);
    expect((await menuService.fetchCategoryNames()), contains('Desserts'));
    expect(await menuService.categoryCupSizeType('Desserts'),
        CategoryCupSizeType.regularAndMedium);
  });

  test('new category stores cup size configuration and uses it for prices',
      () async {
    final menuService = MenuService();
    final err = await menuService.addCategory(
        'Test Snacks', CategoryCupSizeType.regularAndMedium);
    expect(err, isNull);

    final configured = await menuService.categoryCupSizeType('Test Snacks');
    expect(configured, CategoryCupSizeType.regularAndMedium);

    final item = MenuItem(
      id: 'test-snack-item',
      name: 'Cake',
      price: 50,
      icon: '🍰',
      category: 'Test Snacks',
      cupSizeType: CategoryCupSizeType.regularAndMedium,
      cupSize: 'Regular',
      availableCupSizes: ['Regular', 'Medium'],
      priceByCupSize: {'Regular': 50.0, 'Medium': 80.0},
    );

    expect(menuService.priceForCupSize(item, 'Regular'), 50.0);
    expect(menuService.priceForCupSize(item, 'Medium'), 80.0);
    expect(item.availableCupSizes, ['Regular', 'Medium']);
  });

  test('updates a category without changing its ID or detaching menu items',
      () async {
    final menuService = MenuService();
    await menuService.replaceMenuWithStandardSeed();

    final categoryId =
        await menuService.resolveCategoryIdByName('Coffee-espresso base');
    expect(categoryId, isNotNull);

    final error = await menuService.updateCategory(
      categoryId!,
      'Coffee-espresso base',
      'Coffee Series',
      CategoryCupSizeType.twelveOnly,
    );

    expect(error, isNull);
    expect(
        await menuService.resolveCategoryIdByName('Coffee Series'), categoryId);
    expect(await menuService.resolveCategoryIdByName('Coffee-espresso base'),
        isNull);
    expect(await menuService.categoryCupSizeType('Coffee Series'),
        CategoryCupSizeType.twelveOnly);
    expect(
      (await menuService.fetchMenuItems())
          .every((item) => item.category != 'Coffee-espresso base'),
      isTrue,
    );
    expect(
      (await menuService.fetchMenuItems())
          .any((item) => item.category == 'Coffee Series'),
      isTrue,
    );
  });
}
