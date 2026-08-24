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
        {'name': 'Spanish Khalifa', 'price': 60.0, 'icon': '☕', 'badge': '', 'sku': 'CE001'},
        {'name': 'Caramel Macchiato', 'price': 60.0, 'icon': '☕', 'badge': '', 'sku': 'CE002'},
        {'name': 'Himalayan Pink Salt', 'price': 60.0, 'icon': '☕', 'badge': '', 'sku': 'CE003'},
        {'name': 'Flat White', 'price': 60.0, 'icon': '🤍', 'badge': '', 'sku': 'CE004'},
        {'name': 'Long Black', 'price': 60.0, 'icon': '☕', 'badge': '', 'sku': 'CE005'},
        {'name': 'Choco Lava', 'price': 60.0, 'icon': '🍫', 'badge': '', 'sku': 'CE006'},
        {'name': 'Matcha', 'price': 60.0, 'icon': '🍵', 'badge': '', 'sku': 'CE007'},
        {'name': 'Strawberry Matcha', 'price': 60.0, 'icon': '🍓', 'badge': '', 'sku': 'CE008'},
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
    {
      'name': 'Snacks',
      'icon': '🍟',
      'items': [],
    },
  ];
}
