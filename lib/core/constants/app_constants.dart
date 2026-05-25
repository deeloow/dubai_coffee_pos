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
      'name': 'Hot Coffee',
      'icon': '☕',
      'items': [
        {'name': 'Espresso', 'price': 89.0, 'icon': '☕', 'badge': '', 'sku': 'HC001'},
        {'name': 'Americano', 'price': 99.0, 'icon': '🫖', 'badge': '', 'sku': 'HC002'},
        {'name': 'Cappuccino', 'price': 129.0, 'icon': '☕', 'badge': 'Best', 'sku': 'HC003'},
        {'name': 'Latte', 'price': 129.0, 'icon': '🥛', 'badge': '', 'sku': 'HC004'},
        {'name': 'Macchiato', 'price': 119.0, 'icon': '☕', 'badge': '', 'sku': 'HC005'},
        {'name': 'Flat White', 'price': 119.0, 'icon': '🤍', 'badge': '', 'sku': 'HC006'},
        {'name': 'Dubai Karak', 'price': 109.0, 'icon': '🌿', 'badge': 'Local', 'sku': 'HC007'},
        {'name': 'Café Mocha', 'price': 139.0, 'icon': '🍫', 'badge': '', 'sku': 'HC008'},
        {'name': 'Hazelnut Latte', 'price': 149.0, 'icon': '🌰', 'badge': 'New', 'sku': 'HC009'},
      ],
    },
    {
      'name': 'Cold Drinks',
      'icon': '🧊',
      'items': [
        {'name': 'Iced Americano', 'price': 109.0, 'icon': '🧊', 'badge': '', 'sku': 'CD001'},
        {'name': 'Cold Brew', 'price': 139.0, 'icon': '🧋', 'badge': 'Best', 'sku': 'CD002'},
        {'name': 'Iced Latte', 'price': 139.0, 'icon': '🥤', 'badge': '', 'sku': 'CD003'},
        {'name': 'Iced Mocha', 'price': 149.0, 'icon': '🍫', 'badge': '', 'sku': 'CD004'},
        {'name': 'Frappuccino', 'price': 159.0, 'icon': '🧋', 'badge': 'New', 'sku': 'CD005'},
        {'name': 'Lemon Soda', 'price': 89.0, 'icon': '🍋', 'badge': '', 'sku': 'CD006'},
      ],
    },
    {
      'name': 'Pastries',
      'icon': '🥐',
      'items': [
        {'name': 'Croissant', 'price': 89.0, 'icon': '🥐', 'badge': '', 'sku': 'PS001'},
        {'name': 'Muffin', 'price': 79.0, 'icon': '🧁', 'badge': '', 'sku': 'PS002'},
        {'name': 'Cheesecake', 'price': 129.0, 'icon': '🍰', 'badge': 'Best', 'sku': 'PS003'},
        {'name': 'Banana Bread', 'price': 99.0, 'icon': '🍞', 'badge': '', 'sku': 'PS004'},
        {'name': 'Cinnamon Roll', 'price': 109.0, 'icon': '🌀', 'badge': 'New', 'sku': 'PS005'},
        {'name': 'Butter Cookie', 'price': 59.0, 'icon': '🍪', 'badge': '', 'sku': 'PS006'},
      ],
    },
    {
      'name': 'Add-ons',
      'icon': '⚡',
      'items': [
        {'name': 'Extra Shot', 'price': 30.0, 'icon': '⚡', 'badge': '', 'sku': 'AO001'},
        {'name': 'Oat Milk', 'price': 40.0, 'icon': '🌾', 'badge': '', 'sku': 'AO002'},
        {'name': 'Vanilla Syrup', 'price': 25.0, 'icon': '🍯', 'badge': '', 'sku': 'AO003'},
        {'name': 'Caramel Drizzle', 'price': 25.0, 'icon': '🍮', 'badge': '', 'sku': 'AO004'},
        {'name': 'Whipped Cream', 'price': 20.0, 'icon': '🍦', 'badge': '', 'sku': 'AO005'},
        {'name': 'Sugar-free', 'price': 20.0, 'icon': '🌿', 'badge': '', 'sku': 'AO006'},
      ],
    },
  ];
}
