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

// ─── Category Cup Size Config ───────────────────────────────────────────────

enum CategoryCupSizeType {
  twelveAndSixteen,
  twelveOnly,
  sixteenOnly,
  regularAndMedium,
}

extension CategoryCupSizeTypeX on CategoryCupSizeType {
  String get persistedValue {
    switch (this) {
      case CategoryCupSizeType.twelveAndSixteen:
        return 'TWELVE_AND_SIXTEEN';
      case CategoryCupSizeType.twelveOnly:
        return 'TWELVE_ONLY';
      case CategoryCupSizeType.sixteenOnly:
        return 'SIXTEEN_ONLY';
      case CategoryCupSizeType.regularAndMedium:
        return 'REGULAR_AND_MEDIUM';
    }
  }

  List<String> get availableSizes {
    switch (this) {
      case CategoryCupSizeType.twelveAndSixteen:
        return ['12oz', '16oz'];
      case CategoryCupSizeType.twelveOnly:
        return ['12oz'];
      case CategoryCupSizeType.sixteenOnly:
        return ['16oz'];
      case CategoryCupSizeType.regularAndMedium:
        return ['Regular', 'Medium'];
    }
  }

  String get displayLabel {
    switch (this) {
      case CategoryCupSizeType.twelveAndSixteen:
        return '12oz and 16oz';
      case CategoryCupSizeType.twelveOnly:
        return '12oz only';
      case CategoryCupSizeType.sixteenOnly:
        return '16oz only';
      case CategoryCupSizeType.regularAndMedium:
        return 'Regular and Medium';
    }
  }

  static CategoryCupSizeType fromPersisted(String? value) {
    switch (value) {
      case 'TWELVE_AND_SIXTEEN':
        return CategoryCupSizeType.twelveAndSixteen;
      case 'TWELVE_ONLY':
        return CategoryCupSizeType.twelveOnly;
      case 'SIXTEEN_ONLY':
        return CategoryCupSizeType.sixteenOnly;
      case 'REGULAR_AND_MEDIUM':
        return CategoryCupSizeType.regularAndMedium;
      default:
        return CategoryCupSizeType.twelveAndSixteen;
    }
  }
}

// ─── Menu Item ───────────────────────────────────────────────────────────────

class MenuItem {
  static const String defaultDrinkImageAsset = 'assets/icon.png';

  final String id;
  final String name;
  final double price;
  final String icon;
  final String category;
  final String badge;
  final CategoryCupSizeType cupSizeType;
  final String cupSize;
  final List<String> availableCupSizes;
  final Map<String, double> priceByCupSize;
  final String? imagePath;
  final String? imageBase64;
  final String? imageMimeType;
  bool available;

  bool get hasCustomImage {
    if ((imageBase64 ?? '').isNotEmpty) return true;
    if (imagePath == null || imagePath!.isEmpty) return false;
    return !imagePath!.startsWith('assets/');
  }

  String get displayImagePath => hasCustomImage ? (imagePath ?? defaultDrinkImageAsset) : defaultDrinkImageAsset;

  static CategoryCupSizeType inferDefaultCupSizeType(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('snack')) {
      return CategoryCupSizeType.regularAndMedium;
    }
    if (normalized.contains('coffee') || normalized.contains('espresso')) {
      return CategoryCupSizeType.twelveAndSixteen;
    }
    if (normalized.contains('cloud') || normalized.contains('soda') || normalized.contains('lemonade')) {
      return CategoryCupSizeType.sixteenOnly;
    }
    return CategoryCupSizeType.twelveOnly;
  }

  static List<String> cupSizesForType(CategoryCupSizeType type) {
    return type.availableSizes;
  }

  static List<String> _defaultCupSizesForCategory(String category) {
    return cupSizesForType(inferDefaultCupSizeType(category));
  }

  static Map<String, double> _defaultPriceByCupSize(String category, double price) {
    final type = inferDefaultCupSizeType(category);
    switch (type) {
      case CategoryCupSizeType.twelveAndSixteen:
        return {'12oz': 60.0, '16oz': 80.0};
      case CategoryCupSizeType.twelveOnly:
        return {'12oz': price};
      case CategoryCupSizeType.sixteenOnly:
        return {'16oz': price};
      case CategoryCupSizeType.regularAndMedium:
        return {'Regular': price, 'Medium': price};
    }
  }

  static Map<String, double> _parsePriceByCupSize(dynamic raw, {required String category, required double price}) {
    if (raw is Map) {
      final parsed = <String, double>{};
      raw.forEach((key, value) {
        if (key is String && value is num) {
          parsed[key.trim()] = value.toDouble();
        }
      });
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    return _defaultPriceByCupSize(category, price);
  }

  static List<String> _parseCupSizes(dynamic raw, {required String category}) {
    if (raw is List) {
      final values = raw.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (values.isNotEmpty) {
        return values;
      }
    }
    return _defaultCupSizesForCategory(category);
  }

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
    required this.category,
    this.badge = '',
    CategoryCupSizeType? cupSizeType,
    String? cupSize,
    List<String>? availableCupSizes,
    Map<String, double>? priceByCupSize,
    String? imagePath,
    this.imageBase64,
    this.imageMimeType,
    this.available = true,
  })  : cupSizeType = cupSizeType ?? inferDefaultCupSizeType(category),
        cupSize = cupSize ?? cupSizesForType(cupSizeType ?? inferDefaultCupSizeType(category)).first,
        availableCupSizes = availableCupSizes ?? cupSizesForType(cupSizeType ?? inferDefaultCupSizeType(category)),
        priceByCupSize = priceByCupSize ?? _defaultPriceByCupSize(category, price),
        imagePath = imagePath ?? defaultDrinkImageAsset;

  MenuItem copyWith({
    String? id,
    String? name,
    double? price,
    String? icon,
    String? category,
    String? badge,
    CategoryCupSizeType? cupSizeType,
    String? cupSize,
    List<String>? availableCupSizes,
    Map<String, double>? priceByCupSize,
    String? imagePath,
    String? imageBase64,
    String? imageMimeType,
    bool? available,
  }) {
    final resolvedType = cupSizeType ?? this.cupSizeType;
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      badge: badge ?? this.badge,
      cupSizeType: resolvedType,
      cupSize: cupSize ?? this.cupSize,
      availableCupSizes: availableCupSizes ?? this.availableCupSizes,
      priceByCupSize: priceByCupSize ?? this.priceByCupSize,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      imageMimeType: imageMimeType ?? this.imageMimeType,
      available: available ?? this.available,
    );
  }

  factory MenuItem.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawPrice = map['price'];
    final fallbackPrice = rawPrice is num ? rawPrice.toDouble() : 0.0;
    final configuredType = map['cupSizeType'] is String
        ? CategoryCupSizeTypeX.fromPersisted(map['cupSizeType'] as String)
        : inferDefaultCupSizeType(map['category'] ?? '');

    return MenuItem(
        id: id ?? map['id'] ?? '',
        name: map['name'] ?? '',
        price: fallbackPrice,
        icon: map['icon'] ?? '☕',
        category: map['category'] ?? '',
        badge: map['badge'] ?? '',
        cupSizeType: configuredType,
        cupSize: map['cupSize'],
        availableCupSizes: _parseCupSizes(map['availableCupSizes'], category: map['category'] ?? ''),
        priceByCupSize: _parsePriceByCupSize(
          map['priceByCupSize'],
          category: map['category'] ?? '',
          price: fallbackPrice,
        ),
        imagePath: map['imagePath']?.toString() ?? MenuItem.defaultDrinkImageAsset,
        imageBase64: map['imageBase64']?.toString(),
        imageMimeType: map['imageMimeType']?.toString(),
        available: map['available'] ?? true,
      );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'icon': icon,
        'category': category,
        'badge': badge,
        'cupSizeType': cupSizeType.persistedValue,
        'cupSize': cupSize,
        'availableCupSizes': availableCupSizes,
        'priceByCupSize': priceByCupSize,
        'imagePath': imagePath,
        'imageBase64': imageBase64,
        'imageMimeType': imageMimeType,
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
  String cupSize;

  OrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.icon,
    this.qty = 1,
    this.sugarLevel = 'Regular sugar',
    this.cupSize = '12oz',
  });

  OrderItem copyWith({
    String? menuItemId,
    String? name,
    double? price,
    String? icon,
    int? qty,
    String? sugarLevel,
    String? cupSize,
  }) {
    return OrderItem(
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      price: price ?? this.price,
      icon: icon ?? this.icon,
      qty: qty ?? this.qty,
      sugarLevel: sugarLevel ?? this.sugarLevel,
      cupSize: cupSize ?? this.cupSize,
    );
  }

  double get subtotal => price * qty;

  Map<String, dynamic> toMap() =>
      {
        'menuItemId': menuItemId,
        'name': name,
        'price': price,
        'icon': icon,
        'qty': qty,
        'sugarLevel': sugarLevel,
        'cupSize': cupSize,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        menuItemId: map['menuItemId'] ?? '',
        name: map['name'] ?? '',
        price: (map['price'] as num).toDouble(),
        icon: map['icon'] ?? '☕',
        qty: map['qty'] ?? 1,
        sugarLevel: map['sugarLevel'] ?? 'Regular sugar',
        cupSize: map['cupSize'] ?? '12oz',
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

enum OrderStatus { paid, voided, held, checked, ready, completed }
enum PaymentMethod { cash, gcash, card, payMaya }
enum OrderType { dineIn, takeOut }

enum ReportType { daily, monthly }

class DailyReportArchive {
  final String id;
  final ReportType reportType;
  final String label;
  final DateTime generatedAt;
  final DateTime reportDate;
  final int orderCount;
  final double totalRevenue;
  final int receiptCount;
  final int dineInOrderCount;
  final int takeOutOrderCount;
  final double dineInRevenue;
  final double takeOutRevenue;
  final List<Map<String, dynamic>>? receiptData;
  final String? filePath;

  DailyReportArchive({
    required this.id,
    required this.reportType,
    required this.label,
    required this.generatedAt,
    required this.reportDate,
    required this.orderCount,
    required this.totalRevenue,
    required this.receiptCount,
    this.dineInOrderCount = 0,
    this.takeOutOrderCount = 0,
    this.dineInRevenue = 0.0,
    this.takeOutRevenue = 0.0,
    this.receiptData,
    this.filePath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'reportType': reportType.toString().split('.').last,
        'label': label,
        'generatedAt': generatedAt.toIso8601String(),
        'reportDate': reportDate.toIso8601String(),
        'orderCount': orderCount,
        'totalRevenue': totalRevenue,
        'receiptCount': receiptCount,
        'dineInOrderCount': dineInOrderCount,
        'takeOutOrderCount': takeOutOrderCount,
        'dineInRevenue': dineInRevenue,
        'takeOutRevenue': takeOutRevenue,
        'receiptData': receiptData,
        'filePath': filePath,
      };

  factory DailyReportArchive.fromMap(Map<String, dynamic> map) {
    final reportTypeString = map['reportType']?.toString() ?? 'daily';
    final reportType = ReportType.values.firstWhere(
      (type) => type.toString().split('.').last == reportTypeString,
      orElse: () => ReportType.daily,
    );

    return DailyReportArchive(
      id: map['id']?.toString() ?? '',
      reportType: reportType,
      label: map['label']?.toString() ?? 'Daily Report',
      generatedAt: map['generatedAt'] is DateTime
          ? map['generatedAt'] as DateTime
          : DateTime.tryParse(map['generatedAt']?.toString() ?? '') ??
              DateTime.now(),
      reportDate: map['reportDate'] is DateTime
          ? map['reportDate'] as DateTime
          : DateTime.tryParse(map['reportDate']?.toString() ?? '') ??
              DateTime.now(),
      orderCount: (map['orderCount'] as num?)?.toInt() ?? 0,
      totalRevenue: (map['totalRevenue'] as num?)?.toDouble() ?? 0,
      receiptCount: (map['receiptCount'] as num?)?.toInt() ?? 0,
      dineInOrderCount: (map['dineInOrderCount'] as num?)?.toInt() ?? 0,
      takeOutOrderCount: (map['takeOutOrderCount'] as num?)?.toInt() ?? 0,
      dineInRevenue: (map['dineInRevenue'] as num?)?.toDouble() ?? 0.0,
      takeOutRevenue: (map['takeOutRevenue'] as num?)?.toDouble() ?? 0.0,
      receiptData: map['receiptData'] is List
          ? List<Map<String, dynamic>>.from(
              (map['receiptData'] as List).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
            )
          : null,
      filePath: map['filePath']?.toString(),
    );
  }
}

class Order {
  final String id;
  final int orderNumber;
  final String customerName;
  final String cashierName;
  final List<OrderItem> items;
  final double subtotal;
  final double discount;
  final String discountLabel;
  final double total;
  final double tendered;
  final double change;
  final PaymentMethod paymentMethod;
  final String sugarLevel;
  final String orderNotes;
  final bool kitchenCompleted;
  final String preparedBy;
  final bool inventoryDeducted;
  final DateTime createdAt;
  final OrderType orderType;
  final String? voidReason;
  final DateTime? archivedAt;
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
    required this.total,
    required this.tendered,
    required this.change,
    required this.paymentMethod,
    this.sugarLevel = 'Regular sugar',
    this.orderNotes = '',
    this.kitchenCompleted = false,
    this.preparedBy = '',
    this.inventoryDeducted = false,
    this.orderType = OrderType.dineIn,
    required this.createdAt,
    this.status = OrderStatus.paid,
    this.voidReason,
    this.archivedAt,
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
      case OrderStatus.checked:
        return 'checked';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.completed:
        return 'completed';
    }
  }

  String get orderTypeLabel {
    switch (orderType) {
      case OrderType.dineIn:
        return 'Dine-In';
      case OrderType.takeOut:
        return 'Take-Out';
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
    double? total,
    double? tendered,
    double? change,
    PaymentMethod? paymentMethod,
    String? sugarLevel,
    String? orderNotes,
    bool? kitchenCompleted,
    String? preparedBy,
    bool? inventoryDeducted,
    OrderType? orderType,
    DateTime? createdAt,
    OrderStatus? status,
    String? voidReason,
    DateTime? archivedAt,
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
      total: total ?? this.total,
      tendered: tendered ?? this.tendered,
      change: change ?? this.change,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      sugarLevel: sugarLevel ?? this.sugarLevel,
      orderNotes: orderNotes ?? this.orderNotes,
      kitchenCompleted: kitchenCompleted ?? this.kitchenCompleted,
      preparedBy: preparedBy ?? this.preparedBy,
      inventoryDeducted: inventoryDeducted ?? this.inventoryDeducted,
      orderType: orderType ?? this.orderType,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      voidReason: voidReason ?? this.voidReason,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  Order recalculateTotals() {
    final recalculatedSubtotal = items.fold(
      0.0,
      (sum, item) => sum + (item.price * item.qty),
    );
    final normalizedDiscount = discount.clamp(0.0, recalculatedSubtotal);
    return copyWith(
      subtotal: recalculatedSubtotal,
      discount: normalizedDiscount,
      total: recalculatedSubtotal - normalizedDiscount,
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
        'total': total,
        'tendered': tendered,
        'change': change,
        'paymentMethod': paymentMethod.index,
        'sugarLevel': sugarLevel,
        'orderNotes': orderNotes,
        'kitchenCompleted': kitchenCompleted,
        'preparedBy': preparedBy,
        'inventoryDeducted': inventoryDeducted,
        'orderType': orderType.index,
        'createdAt': createdAt.toIso8601String(),
        'status': status.index,
        'voidReason': voidReason,
        'archivedAt': archivedAt?.toIso8601String(),
      };

  factory Order.fromMap(Map<String, dynamic> map, {String? id}) => Order(
        id: id ?? map['id'] ?? '',
        orderNumber: map['orderNumber'] ?? 0,
        customerName: map['customerName'] ?? '',
        cashierName: map['cashierName'] ?? '',
        items: (map['items'] as List<dynamic>? ?? [])
          .map((i) => OrderItem.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList(),
        subtotal: (map['subtotal'] as num).toDouble(),
        discount: (map['discount'] as num).toDouble(),
        discountLabel: map['discountLabel'] ?? '',
        total: (map['total'] as num).toDouble(),
        tendered: (map['tendered'] as num).toDouble(),
        change: (map['change'] as num).toDouble(),
        paymentMethod: PaymentMethod.values[map['paymentMethod'] ?? 0],
        sugarLevel: map['sugarLevel'] ?? 'Regular sugar',
        orderNotes: (map['orderNotes'] ?? map['specialInstructions'] ?? '').toString(),
        kitchenCompleted: map['kitchenCompleted'] ?? false,
        preparedBy: map['preparedBy']?.toString() ?? '',
        inventoryDeducted: map['inventoryDeducted'] ?? false,
        orderType: map['orderType'] is int
            ? OrderType.values[map['orderType'] as int]
            : (map['orderType']?.toString().toLowerCase().contains('take') ?? false)
                ? OrderType.takeOut
                : OrderType.dineIn,
        createdAt: map['createdAt'] is DateTime
            ? map['createdAt'] as DateTime
            : DateTime.parse(map['createdAt'] as String),
        status: OrderStatus.values[map['status'] ?? 0],
        voidReason: map['voidReason']?.toString(),
        archivedAt: map['archivedAt'] is DateTime
            ? map['archivedAt'] as DateTime
            : map['archivedAt'] != null
                ? DateTime.tryParse(map['archivedAt'] as String)
                : null,
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

  InventoryItem copyWith({
    String? id,
    String? name,
    String? unit,
    double? quantity,
    double? servedQuantity,
    double? lowStockThreshold,
    double? costPerUnit,
    String? category,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      servedQuantity: servedQuantity ?? this.servedQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
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
          .map((i) => RecipeIngredient.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList(),
      );
}
