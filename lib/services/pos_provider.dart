import 'package:flutter/foundation.dart';
import '../models/models.dart';

class PosProvider extends ChangeNotifier {
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

  void addItem(MenuItem menuItem) {
    final idx = _items.indexWhere((i) => i.menuItemId == menuItem.id);
    if (idx >= 0) {
      _items[idx].qty++;
    } else {
      _items.add(OrderItem(
        menuItemId: menuItem.id,
        name: _displayName(menuItem),
        price: menuItem.price,
        icon: menuItem.icon,
        sugarLevel: 'Regular sugar',
      ));
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
