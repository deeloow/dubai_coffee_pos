// lib/core/constants/app_constants.dart

class AppConstants {
  static const String appName = 'Dubai Coffee';
  static const String appSubtitle = 'POS System';

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleBarista = 'barista';

  // Firestore collections
  static const String colUsers = 'users';
  static const String colOrders = 'orders';
  static const String colInventory = 'inventory';
  static const String colKds = 'kds';

  // VAT
  static const double vatRate = 0.12;

  // Discount types
  static const String discNone = 'none';
  static const String discPercent = 'percent';
  static const String discFlat = 'flat';
  static const String discSenior = 'senior';
  static const String discStaff = 'staff';

  // Order status
  static const String statusPaid = 'paid';
  static const String statusVoid = 'void';
  static const String statusHeld = 'held';

  // Low stock threshold
  static const int lowStockThreshold = 10;
}

class MenuData {
  static const List<Map<String, dynamic>> categories = [
    {
      'name': 'Coffee-espresso base',
      'icon': '☕',
      'items': [
        {'name': 'Spanish Khalifa 12oz', 'price': 50.0, 'icon': '☕', 'badge': '', 'sku': 'CE001'},
        {'name': 'Spanish Khalifa 16oz', 'price': 80.0, 'icon': '☕', 'badge': '', 'sku': 'CE002'},
        {'name': 'Caramel Macchiato 12oz', 'price': 60.0, 'icon': '☕', 'badge': '', 'sku': 'CE003'},
        {'name': 'Caramel Macchiato 16oz', 'price': 80.0, 'icon': '☕', 'badge': '', 'sku': 'CE004'},
        {'name': 'Himalayan Pink Salt 12oz', 'price': 60.0, 'icon': '☕', 'badge': '', 'sku': 'CE005'},
        {'name': 'Himalayan Pink Salt 16oz', 'price': 80.0, 'icon': '☕', 'badge': '', 'sku': 'CE006'},
        {'name': 'Flat White 12oz', 'price': 60.0, 'icon': '🤍', 'badge': '', 'sku': 'CE007'},
        {'name': 'Flat White 16oz', 'price': 80.0, 'icon': '🤍', 'badge': '', 'sku': 'CE008'},
        {'name': 'Long Black 12oz', 'price': 50.0, 'icon': '☕', 'badge': '', 'sku': 'CE009'},
        {'name': 'Long Black 16oz', 'price': 80.0, 'icon': '☕', 'badge': '', 'sku': 'CE010'},
        {'name': 'Choco Lava 12oz', 'price': 60.0, 'icon': '🍫', 'badge': '', 'sku': 'CE011'},
        {'name': 'Choco Lava 16oz', 'price': 80.0, 'icon': '🍫', 'badge': '', 'sku': 'CE012'},
        {'name': 'Matcha 12oz', 'price': 60.0, 'icon': '🍵', 'badge': '', 'sku': 'CE013'},
        {'name': 'Matcha 16oz', 'price': 80.0, 'icon': '🍵', 'badge': '', 'sku': 'CE014'},
        {'name': 'Strawberry Matcha 12oz', 'price': 60.0, 'icon': '🍓', 'badge': '', 'sku': 'CE015'},
        {'name': 'Strawberry Matcha 16oz', 'price': 80.0, 'icon': '🍓', 'badge': '', 'sku': 'CE016'},
      ],
    },
    {
      'name': 'Cloud series',
      'icon': '☁',
      'items': [
        {'name': 'Chocolate', 'price': 50.0, 'icon': '🍫', 'badge': '', 'sku': 'CL001'},
        {'name': 'Strawberry', 'price': 50.0, 'icon': '🍓', 'badge': '', 'sku': 'CL002'},
        {'name': 'Matcha', 'price': 50.0, 'icon': '🍵', 'badge': '', 'sku': 'CL003'},
        {'name': 'Cookies & Cream', 'price': 50.0, 'icon': '🍪', 'badge': '', 'sku': 'CL004'},
        {'name': 'Cookies Matcha', 'price': 50.0, 'icon': '🍪', 'badge': '', 'sku': 'CL005'},
        {'name': 'Strawberry Matcha', 'price': 50.0, 'icon': '🍓', 'badge': '', 'sku': 'CL006'},
      ],
    },
    {
      'name': 'Soda base',
      'icon': '🥤',
      'items': [
        {'name': 'Green Apple', 'price': 50.0, 'icon': '🍏', 'badge': '', 'sku': 'SD001'},
        {'name': 'Strawberry', 'price': 50.0, 'icon': '🍓', 'badge': '', 'sku': 'SD002'},
      ],
    },
    {
      'name': 'Lemonade-freshly squeeze',
      'icon': '🍋',
      'items': [
        {'name': 'Fresh Lemon', 'price': 50.0, 'icon': '🍋', 'badge': '', 'sku': 'LM001'},
        {'name': 'Strawberry', 'price': 50.0, 'icon': '🍓', 'badge': '', 'sku': 'LM002'},
      ],
    },
  ];
}
