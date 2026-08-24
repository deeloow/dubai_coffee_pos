import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'menu_service.dart';

class PosProvider extends ChangeNotifier {
  final MenuService _menuService = MenuService();
  List<OrderItem> _items = [];
  String _customerName = '';
  DiscountInfo _discount = const DiscountInfo();
  String _currentCategory = 'All';
  String _searchQuery = '';

  List<OrderItem> get items => List.unmodifiable(_items);
  String get customerName => _customerName;
  DiscountInfo get discount => _discount;
  String get currentCategory => _currentCategory;
  String get searchQuery => _searchQuery;

  // ── Customer ──────────────────────────────────────────────────────────────
  void setCustomerName(String name) {
    _customerName = name;
    notifyListeners();
  }

  // ── Category / Search ─────────────────────────────────────────────────────
  void setCategory(String cat) {
    _currentCategory = cat;
    _searchQuery = '';
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void refreshPricesFromMenu() {
    final updatedItems = _items.map((item) {
      final menuItem = _menuService.getMenuItemById(item.menuItemId);
      if (menuItem == null) return item;

      final updatedPrice = _menuService.priceForCupSize(menuItem, item.cupSize);
      if ((updatedPrice - item.price).abs() < 0.0001) {
        return item;
      }
      return item.copyWith(price: updatedPrice);
    }).toList();

    final changed = _items.length != updatedItems.length ||
        updatedItems.asMap().entries.any((entry) {
          final index = entry.key;
          return (entry.value.price - _items[index].price).abs() > 0.0001;
        });

    if (changed) {
      _items = updatedItems;
      notifyListeners();
    }
  }

  // ── Cart ──────────────────────────────────────────────────────────────────
  String _displayName(MenuItem menuItem) {
    final category = menuItem.category.trim();
    final name = menuItem.name.trim();

    if (category.toLowerCase().contains('coffee-espresso base')) {
      return name;
    }

    if (category.toLowerCase().contains('cloud')) {
      return 'Cloud Series - $name';
    }
    if (category.toLowerCase().contains('soda')) {
      return 'Soda - $name';
    }
    if (category.toLowerCase().contains('lemonade')) {
      return 'Lemonade - $name';
    }

    return '$category - $name';
  }

  String _resolveCupSize(MenuItem menuItem, {String? explicitCupSize}) {
    final normalized = (explicitCupSize ?? menuItem.cupSize).trim();
    if (normalized.isNotEmpty) {
      if (explicitCupSize != null) {
        return normalized;
      }

      switch (menuItem.cupSizeType) {
        case CategoryCupSizeType.regularAndMedium:
          return normalized.contains('Medium') || normalized.contains('Regular') ? normalized : 'Regular';
        case CategoryCupSizeType.twelveOnly:
          return '12oz';
        case CategoryCupSizeType.sixteenOnly:
          return '16oz';
        case CategoryCupSizeType.twelveAndSixteen:
          return normalized;
      }
    }

    switch (menuItem.cupSizeType) {
      case CategoryCupSizeType.regularAndMedium:
        return 'Regular';
      case CategoryCupSizeType.twelveOnly:
        return '12oz';
      case CategoryCupSizeType.sixteenOnly:
        return '16oz';
      case CategoryCupSizeType.twelveAndSixteen:
        return '12oz';
    }
  }

  double _resolvePrice(MenuItem menuItem, String cupSize, {double? explicitPrice}) {
    if (explicitPrice != null) {
      return explicitPrice;
    }

    return _menuService.priceForCupSize(menuItem, cupSize);
  }

  void addItem(MenuItem menuItem) {
    final cupSize = _resolveCupSize(menuItem);
    final idx = _items.indexWhere(
      (i) => i.menuItemId == menuItem.id && i.cupSize == cupSize,
    );

    if (idx >= 0) {
      _items[idx].qty++;
    } else {
      final isSnack = menuItem.cupSizeType == CategoryCupSizeType.regularAndMedium;
      _items.add(OrderItem(
        menuItemId: menuItem.id,
        name: _displayName(menuItem),
        price: _resolvePrice(menuItem, cupSize),
        icon: menuItem.icon,
        sugarLevel: isSnack ? '' : 'Regular sugar',
        cupSize: cupSize,
      ));
    }
    notifyListeners();
  }

  void addItemWithCupSize(MenuItem menuItem, String cupSize, {double? price}) {
    final normalizedCupSize = _resolveCupSize(menuItem, explicitCupSize: cupSize);
    final resolvedPrice = _resolvePrice(menuItem, normalizedCupSize, explicitPrice: price);
    final isSnack = menuItem.cupSizeType == CategoryCupSizeType.regularAndMedium;
    final idx = _items.indexWhere(
      (i) => i.menuItemId == menuItem.id && i.cupSize == normalizedCupSize,
    );

    if (idx >= 0) {
      _items[idx].qty++;
      _items[idx] = _items[idx].copyWith(price: resolvedPrice);
    } else {
      _items.add(OrderItem(
        menuItemId: menuItem.id,
        name: _displayName(menuItem),
        price: resolvedPrice,
        icon: menuItem.icon,
        sugarLevel: isSnack ? '' : 'Regular sugar',
        cupSize: normalizedCupSize,
      ));
    }
    notifyListeners();
  }

  /// Set the sugar level for a specific cart item.
  void setItemSugarLevel(int index, String sugar) {
    if (index < 0 || index >= _items.length) return;
    _items[index] = _items[index].copyWith(sugarLevel: sugar);
    notifyListeners();
  }

  /// Set the cup size for a cart item, updating the existing row for snacks and
  /// merging only for drink variants that intentionally use separate size lines.
  void setItemCupSize(int index, String menuItemId, String cupSize, double price) {
    if (index < 0 || index >= _items.length) return;

    final current = _items[index];
    final normalizedCupSize = (cupSize.isNotEmpty ? cupSize : current.cupSize).trim();
    if (current.cupSize == normalizedCupSize) return;

    final isSnack = normalizedCupSize.toLowerCase().contains('regular') ||
        normalizedCupSize.toLowerCase().contains('medium') ||
        current.cupSize.toLowerCase().contains('regular') ||
        current.cupSize.toLowerCase().contains('medium');

    if (isSnack) {
      // Snack size is an editable property of the existing cart row.
      // Updating the row keeps a single item and preserves its quantity.
      _items[index] = current.copyWith(
        cupSize: normalizedCupSize,
        price: price,
        sugarLevel: '',
      );
    } else {
      final existingIndex = _items.indexWhere(
        (i) => i.menuItemId == menuItemId && i.cupSize == normalizedCupSize,
      );

      if (existingIndex >= 0) {
        final mergedQty = current.qty + _items[existingIndex].qty;
        _items[existingIndex] = _items[existingIndex].copyWith(
          qty: mergedQty,
          price: price,
          sugarLevel: current.sugarLevel,
        );
        _items.removeAt(index);
      } else {
        _items[index] = current.copyWith(
          cupSize: normalizedCupSize,
          price: price,
        );
      }
    }

    notifyListeners();
  }

  /// Set the sugar level for all items currently in the cart.
  void setSugarForAll(String sugar) {
    for (final it in _items) {
      it.sugarLevel = sugar;
    }
    notifyListeners();
  }

  void changeQty(int index, int delta) {
    _items[index].qty += delta;
    if (_items[index].qty <= 0) _items.removeAt(index);
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void clearOrder() {
    _items = [];
    _customerName = '';
    _discount = const DiscountInfo();
    notifyListeners();
  }

  // ── Discount ──────────────────────────────────────────────────────────────
  void setDiscount(DiscountInfo d) {
    _discount = d;
    notifyListeners();
  }

  // ── Totals ────────────────────────────────────────────────────────────────
  double get subtotal => _items.fold(0, (s, i) => s + i.price * i.qty);

  double get discountAmount => _discount.apply(subtotal);

  double get discounted => subtotal - discountAmount;

  double get total => discounted;

  bool get isEmpty => _items.isEmpty;
  bool get hasCustomer => _customerName.trim().isNotEmpty;
}
