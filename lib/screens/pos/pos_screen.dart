import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/pos_provider.dart';
import '../../services/menu_service.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import 'customer_name_sheet.dart';
import 'cart_sheet.dart';
import 'receipt_list_sheet.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {

  final MenuService _menuSvc = MenuService();
  final _searchCtrl = TextEditingController();

  static const categories = [
    'Coffee-espresso base',
    'Cloud series',
    'Soda base',
    'Lemonade-freshly squeeze'
  ];

  @override
  void initState() {
    super.initState();
    // Always reset menu to standard seed when Cashier page loads
    _menuSvc.replaceMenuWithStandardSeed();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showCustomerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CustomerNameSheet(),
    );
  }

  void _showCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CartSheet(),
    );
  }

  void _showReceiptList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptListSheet(parentContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.espresso,
        title: const Row(
          children: [
            Text('☕ ', style: TextStyle(fontSize: 18)),
            Text('Dubai Coffee'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showReceiptList(context),
            icon: const Icon(Icons.receipt_long_outlined,
                color: AppColors.goldLight),
            tooltip: 'Receipt list',
          ),
          if (pos.hasCustomer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.darkBrown,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 14, color: AppColors.goldLight),
                      const SizedBox(width: 4),
                      AppText(pos.customerName,
                          size: 12, color: AppColors.goldLight),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.darkBrown,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AppText(auth.user?.name ?? 'Cashier',
                    size: 12, color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Customer name banner
          if (!pos.hasCustomer)
            GestureDetector(
              onTap: () => _showCustomerSheet(context),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFFFF8E1),
                child: const Row(
                  children: [
                    Icon(Icons.person_add_outlined,
                        size: 16, color: AppColors.gold),
                    SizedBox(width: 8),
                    AppText('Tap to enter customer name before ordering',
                        size: 12, color: AppColors.goldDark),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios,
                        size: 12, color: AppColors.gold),
                  ],
                ),
              ),
            ),

          // Search bar
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: pos.setSearchQuery,
              style: const TextStyle(fontSize: 13, color: AppColors.espresso),
              decoration: InputDecoration(
                hintText: 'Search menu...',
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppColors.textMuted),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: pos.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            size: 16, color: AppColors.textMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          pos.setSearchQuery('');
                        })
                    : null,
              ),
            ),
          ),

          // Category bar
          if (pos.searchQuery.isEmpty)
            Container(
              height: 40,
              color: AppColors.bgLight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: categories.length,
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final active = pos.currentCategory == cat;
                  return GestureDetector(
                    onTap: () => pos.setCategory(cat),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 0),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? AppColors.espresso : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: AppText(cat,
                          size: 12,
                          weight: active ? FontWeight.w600 : FontWeight.normal,
                          color:
                              active ? AppColors.goldLight : AppColors.brown2),
                    ),
                  );
                },
              ),
            ),

          // Menu grid
          Expanded(
            child: StreamBuilder<List<MenuItem>>(
              stream: _menuSvc.menuStream(),
              initialData: const [],
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Text('Unable to load menu items.'),
                  );
                }

                final allItems = snap.data!;
                final List<MenuItem> items;

                if (pos.searchQuery.isNotEmpty) {
                  items = allItems
                      .where((i) => i.name
                          .toLowerCase()
                          .contains(pos.searchQuery.toLowerCase()))
                      .toList();
                } else if (pos.currentCategory == 'All') {
                  items = allItems;
                } else {
                  items = allItems
                      .where((i) => i.category == pos.currentCategory)
                      .toList();
                }

                if (items.isEmpty) {
                  return const EmptyState(
                      message: 'No items found',
                      icon: Icons.search_off_outlined);
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _MenuCard(
                    item: items[i],
                    onTap: () {
                      if (!pos.hasCustomer) {
                        _showCustomerSheet(context);
                        return;
                      }
                      pos.addItem(items[i]);
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${items[i].name} added'),
                          duration: const Duration(milliseconds: 800),
                          backgroundColor: AppColors.espresso,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // Cart FAB
      floatingActionButton: pos.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showCart(context),
              backgroundColor: AppColors.espresso,
              icon: const Icon(Icons.shopping_cart_outlined,
                  color: AppColors.goldLight),
              label: Row(
                children: [
                  AppText('${pos.items.fold(0, (s, i) => s + i.qty)} items',
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.goldLight),
                  const SizedBox(width: 8),
                  AppText(formatPHP(pos.total),
                      size: 13, weight: FontWeight.w700, color: AppColors.gold),
                ],
              ),
            ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;

  const _MenuCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.available ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: item.available ? AppColors.white : AppColors.bgLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderColor, width: 0.5),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.icon,
                      style: TextStyle(
                          fontSize: 26,
                          color: item.available ? null : Colors.grey)),
                  const SizedBox(height: 4),
                  AppText(item.name,
                      size: 10,
                      weight: FontWeight.w500,
                      align: TextAlign.center,
                      color: item.available
                          ? AppColors.espresso
                          : AppColors.textMuted),
                  const SizedBox(height: 3),
                  AppText(formatPHP(item.price),
                      size: 11,
                      weight: FontWeight.w600,
                      color: item.available
                          ? AppColors.goldDark
                          : AppColors.textMuted),
                ],
              ),
            ),
            if (item.badge.isNotEmpty)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: AppText(item.badge,
                      size: 8,
                      weight: FontWeight.w600,
                      color: AppColors.espresso),
                ),
              ),
            if (!item.available)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: AppText('Unavailable',
                        size: 10, color: AppColors.textMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
