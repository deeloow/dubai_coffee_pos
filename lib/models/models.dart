// ─── User / Auth ────────────────────────────────────────────────────────────

enum UserRole { admin, barista }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        role: map['role'] == 'admin' ? UserRole.admin : UserRole.barista,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role == UserRole.admin ? 'admin' : 'barista',
      };
}

// ─── Assignment ──────────────────────────────────────────────────────────────

class Assignment {
  final String id;
  final String baristaId;
  final String baristaName;
  final String assignedBy;
  final String shift;
  final String type;
  final DateTime date;
  final DateTime createdAt;
  final bool synced;

  Assignment({
    required this.id,
    required this.baristaId,
    required this.baristaName,
    required this.assignedBy,
    required this.shift,
    this.type = 'manual',
    required this.date,
    required this.createdAt,
    this.synced = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'baristaId': baristaId,
        'baristaName': baristaName,
        'assignedBy': assignedBy,
        'shift': shift,
        'type': type,
        'date': date.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'synced': synced,
      };

  Map<String, dynamic> toRemoteMap() => {
        'id': id,
        'baristaId': baristaId,
        'baristaName': baristaName,
        'assignedBy': assignedBy,
        'shift': shift,
        'type': type,
        'date': date.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  Assignment copyWith({
    String? id,
    String? baristaId,
    String? baristaName,
    String? assignedBy,
    String? shift,
    String? type,
    DateTime? date,
    DateTime? createdAt,
    bool? synced,
  }) {
    return Assignment(
      id: id ?? this.id,
      baristaId: baristaId ?? this.baristaId,
      baristaName: baristaName ?? this.baristaName,
      assignedBy: assignedBy ?? this.assignedBy,
      shift: shift ?? this.shift,
      type: type ?? this.type,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  factory Assignment.fromMap(Map<String, dynamic> map) => Assignment(
        id: map['id'] ?? '',
        baristaId: map['baristaId'] ?? '',
        baristaName: map['baristaName'] ?? '',
        assignedBy: map['assignedBy'] ?? '',
        shift: map['shift'] ?? '',
        type: map['type'] ?? 'manual',
        date: DateTime.parse(map['date'] as String),
        createdAt: DateTime.parse(map['createdAt'] as String),
        synced: map['synced'] ?? true,
      );
}

// ─── Menu Item ───────────────────────────────────────────────────────────────

class MenuItem {
  final String id;
  final String name;
  final double price;
  final String icon;
  final String category;
  final String badge;
  bool available;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
    required this.category,
    this.badge = '',
    this.available = true,
  });

  factory MenuItem.fromMap(Map<String, dynamic> map, {String? id}) =>
      MenuItem(
        id: id ?? map['id'] ?? '',
        name: map['name'] ?? '',
        price: (map['price'] as num).toDouble(),
        icon: map['icon'] ?? '☕',
        category: map['category'] ?? '',
        badge: map['badge'] ?? '',
        available: map['available'] ?? true,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'icon': icon,
        'category': category,
        'badge': badge,
        'available': available,
      };
}

// ─── Order Item ──────────────────────────────────────────────────────────────

class OrderItem {
  final String menuItemId;
  final String name;
  final double price;
  final String icon;
  int qty;
  String sugarLevel;

  OrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.icon,
    this.qty = 1,
    this.sugarLevel = 'Regular sugar',
  });

  double get subtotal => price * qty;

  Map<String, dynamic> toMap() =>
      {
        'menuItemId': menuItemId,
        'name': name,
        'price': price,
        'icon': icon,
        'qty': qty,
        'sugarLevel': sugarLevel,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        menuItemId: map['menuItemId'] ?? '',
        name: map['name'] ?? '',
        price: (map['price'] as num).toDouble(),
        icon: map['icon'] ?? '☕',
        qty: map['qty'] ?? 1,
        sugarLevel: map['sugarLevel'] ?? 'Regular sugar',
      );
}

// ─── Discount ────────────────────────────────────────────────────────────────

enum DiscountType { none, percent, flat, senior, staff }

class DiscountInfo {
  final DiscountType type;
  final double value;

  const DiscountInfo({this.type = DiscountType.none, this.value = 0});

  double apply(double subtotal) {
    switch (type) {
      case DiscountType.percent:
        return subtotal * (value.clamp(0, 100) / 100);
      case DiscountType.flat:
        return value.clamp(0, subtotal);
      case DiscountType.senior:
        return subtotal * 0.20;
      case DiscountType.staff:
        return subtotal * 0.15;
      default:
        return 0;
    }
  }

  String get label {
    switch (type) {
      case DiscountType.percent:
        return 'Discount ($value%)';
      case DiscountType.flat:
        return 'Fixed discount';
      case DiscountType.senior:
        return 'Senior/PWD (20%)';
      case DiscountType.staff:
        return 'Staff (15%)';
      default:
        return 'No discount';
    }
  }
}

// ─── Order ───────────────────────────────────────────────────────────────────

enum OrderStatus { paid, voided, held }
enum PaymentMethod { cash, gcash, card, payMaya }

class Order {
  final String id;
  final int orderNumber;
  final String customerName;
  final String cashierName;
  final List<OrderItem> items;
  final double subtotal;
  final double discount;
  final String discountLabel;
  final double vat;
  final double total;
  final double tendered;
  final double change;
  final PaymentMethod paymentMethod;
  final String sugarLevel;
  final bool kitchenCompleted;
  final DateTime createdAt;
  OrderStatus status;

  Order({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.cashierName,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.discountLabel,
    required this.vat,
    required this.total,
    required this.tendered,
    required this.change,
    required this.paymentMethod,
    this.sugarLevel = 'Regular sugar',
    this.kitchenCompleted = false,
    required this.createdAt,
    this.status = OrderStatus.paid,
  });

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.gcash:
        return 'GCash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.payMaya:
        return 'PayMaya';
    }
  }

  String get statusLabel {
    switch (status) {
      case OrderStatus.paid:
        return 'paid';
      case OrderStatus.voided:
        return 'void';
      case OrderStatus.held:
        return 'held';
    }
  }

  Order copyWith({
    String? id,
    int? orderNumber,
    String? customerName,
    String? cashierName,
    List<OrderItem>? items,
    double? subtotal,
    double? discount,
    String? discountLabel,
    double? vat,
    double? total,
    double? tendered,
    double? change,
    PaymentMethod? paymentMethod,
    String? sugarLevel,
    bool? kitchenCompleted,
    DateTime? createdAt,
    OrderStatus? status,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerName: customerName ?? this.customerName,
      cashierName: cashierName ?? this.cashierName,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      discountLabel: discountLabel ?? this.discountLabel,
      vat: vat ?? this.vat,
      total: total ?? this.total,
      tendered: tendered ?? this.tendered,
      change: change ?? this.change,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      sugarLevel: sugarLevel ?? this.sugarLevel,
      kitchenCompleted: kitchenCompleted ?? this.kitchenCompleted,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderNumber': orderNumber,
        'customerName': customerName,
        'cashierName': cashierName,
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'discountLabel': discountLabel,
        'vat': vat,
        'total': total,
        'tendered': tendered,
        'change': change,
        'paymentMethod': paymentMethod.index,
        'sugarLevel': sugarLevel,
        'kitchenCompleted': kitchenCompleted,
        'createdAt': createdAt.toIso8601String(),
        'status': status.index,
      };

  factory Order.fromMap(Map<String, dynamic> map, {String? id}) => Order(
        id: id ?? map['id'] ?? '',
        orderNumber: map['orderNumber'] ?? 0,
        customerName: map['customerName'] ?? '',
        cashierName: map['cashierName'] ?? '',
        items: (map['items'] as List<dynamic>? ?? [])
            .map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
            .toList(),
        subtotal: (map['subtotal'] as num).toDouble(),
        discount: (map['discount'] as num).toDouble(),
        discountLabel: map['discountLabel'] ?? '',
        vat: (map['vat'] as num).toDouble(),
        total: (map['total'] as num).toDouble(),
        tendered: (map['tendered'] as num).toDouble(),
        change: (map['change'] as num).toDouble(),
        paymentMethod: PaymentMethod.values[map['paymentMethod'] ?? 0],
        sugarLevel: map['sugarLevel'] ?? 'Regular sugar',
        kitchenCompleted: map['kitchenCompleted'] ?? false,
        createdAt: map['createdAt'] is DateTime
            ? map['createdAt'] as DateTime
            : DateTime.parse(map['createdAt'] as String),
        status: OrderStatus.values[map['status'] ?? 0],
      );
}

// ─── Inventory Item ──────────────────────────────────────────────────────────

enum StockStatus { inStock, low, outOfStock }

class InventoryItem {
  final String id;
  String name;
  String unit;
  double quantity;
  double servedQuantity;
  double lowStockThreshold;
  double costPerUnit;
  String category;

  InventoryItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    this.servedQuantity = 0.0,
    required this.lowStockThreshold,
    required this.costPerUnit,
    required this.category,
  });

  StockStatus get stockStatus {
    if (quantity <= 0) return StockStatus.outOfStock;
    if (quantity <= lowStockThreshold) return StockStatus.low;
    return StockStatus.inStock;
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'unit': unit,
        'quantity': quantity,
        'servedQuantity': servedQuantity,
        'lowStockThreshold': lowStockThreshold,
        'costPerUnit': costPerUnit,
        'category': category,
      };

  factory InventoryItem.fromMap(Map<String, dynamic> map, {String? id}) =>
      InventoryItem(
        id: id ?? map['id'] ?? '',
        name: map['name'] ?? '',
        unit: map['unit'] ?? 'pcs',
        quantity: (map['quantity'] as num).toDouble(),
        servedQuantity: (map['servedQuantity'] as num?)?.toDouble() ?? 0.0,
        lowStockThreshold: (map['lowStockThreshold'] as num).toDouble(),
        costPerUnit: (map['costPerUnit'] as num).toDouble(),
        category: map['category'] ?? '',
      );
}

// ─── Recipe (Menu Item → Inventory Ingredients) ──────────────────────────────

class RecipeIngredient {
  final String inventoryItemId;
  final String inventoryItemName;
  final double quantityNeeded;

  RecipeIngredient({
    required this.inventoryItemId,
    required this.inventoryItemName,
    required this.quantityNeeded,
  });

  Map<String, dynamic> toMap() => {
        'inventoryItemId': inventoryItemId,
        'inventoryItemName': inventoryItemName,
        'quantityNeeded': quantityNeeded,
      };

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) =>
      RecipeIngredient(
        inventoryItemId: map['inventoryItemId'] ?? '',
        inventoryItemName: map['inventoryItemName'] ?? '',
        quantityNeeded: (map['quantityNeeded'] as num).toDouble(),
      );
}

class Recipe {
  final String id;
  final String menuItemName;
  final List<RecipeIngredient> ingredients;

  Recipe({
    required this.id,
    required this.menuItemName,
    required this.ingredients,
  });

  Map<String, dynamic> toMap() => {
        'menuItemName': menuItemName,
        'ingredients': ingredients.map((i) => i.toMap()).toList(),
      };

  factory Recipe.fromMap(Map<String, dynamic> map, {String? id}) => Recipe(
        id: id ?? map['id'] ?? '',
        menuItemName: map['menuItemName'] ?? '',
        ingredients: (map['ingredients'] as List<dynamic>? ?? [])
            .map((i) => RecipeIngredient.fromMap(i as Map<String, dynamic>))
            .toList(),
      );
}
