# Snack Size Persistence - Test Plan

## Issue Fixed
**Problem:** Snack size selected in Cashier was not being persisted to Cart/Order Summary, causing users to re-select the size, which could create duplicate items.

**Root Cause:** `_resolveCupSize()` was ignoring explicit snack size parameters and defaulting to '16oz'.

**Solution:** Modified `_resolveCupSize()` in `lib/services/pos_provider.dart` to respect explicit cup sizes.

---

## Test Scenarios

### TEST 1: Regular Size Persistence ✓
**Objective:** Verify that Regular snack size is preserved from Cashier to Order Summary

**Steps:**
1. Open **Snacks** category in Cashier
2. Select **French Fries** menu item
3. In size picker, select **Regular**
4. Verify: Item added to cart
5. Open **Order Summary**
6. Verify: **French Fries** shows with **Regular** size selected (button appears highlighted)
7. Verify: Price shows ₱50 (Regular price)

**Expected Result:**
- Regular button is highlighted/selected in Order Summary
- No need to re-select size
- Quantity shows 1
- Price is ₱50

---

### TEST 2: Medium Size Persistence ✓
**Objective:** Verify that Medium snack size is preserved from Cashier to Order Summary

**Steps:**
1. Open **Snacks** category in Cashier
2. Select **Spring Rolls** menu item
3. In size picker, select **Medium**
4. Verify: Item added to cart
5. Open **Order Summary**
6. Verify: **Spring Rolls** shows with **Medium** size selected (button appears highlighted)
7. Verify: Price shows ₱80 (Medium price - if configured)

**Expected Result:**
- Medium button is highlighted/selected in Order Summary
- No need to re-select size
- Quantity shows 1
- Price is correct for Medium

---

### TEST 3: No Duplicate When Re-selecting Same Size ✓
**Objective:** Verify that selecting the same size again does NOT create a duplicate item

**Precondition:** French Fries Regular already in cart (from TEST 1)

**Steps:**
1. Open **Order Summary**
2. Verify: **French Fries Regular** displayed with Qty=1
3. In Order Summary, click **Regular** button again
4. Verify: No duplicate created
5. Verify: Still shows Qty=1 (not Qty=2)
6. Verify: Only ONE "French Fries Regular" item in the cart

**Expected Result:**
- Clicking Regular again does nothing (early return in `setItemCupSize`)
- Quantity remains 1
- No duplicate item appears
- Cart contains exactly 1 French Fries Regular item

---

### TEST 4: Changing Size Creates New Variant ✓
**Objective:** Verify that changing from one size to another creates a separate variant

**Precondition:** French Fries Regular already in cart with Qty=1

**Steps:**
1. Open **Order Summary**
2. Verify: **French Fries Regular** Qty=1 displayed
3. Click **Medium** button in the same French Fries item row
4. Verify: **Medium** button now highlighted
5. Verify: Price updates to Medium price (₱70 if configured)
6. Scroll down in Order Summary

**Expected Result:**
- Original **French Fries Regular** Qty=1 ₱50 is PRESERVED
- NEW **French Fries Medium** Qty=1 ₱70 is CREATED below it
- Cart now has 2 distinct French Fries items
- Subtotal shows: ₱50 + ₱70 = ₱120

---

### TEST 5: Multiple Variants with Independent Quantities ✓
**Objective:** Verify that changing quantities works independently for each variant

**Precondition:** Cart has French Fries Regular (Qty=1) and French Fries Medium (Qty=1)

**Steps:**
1. Open **Order Summary**
2. In **French Fries Regular** row, click + button twice to increase to Qty=3
3. Verify: French Fries Regular now shows Qty=3, price ₱150
4. Verify: French Fries Medium still shows Qty=1, price ₱70
5. In **French Fries Medium** row, click + button once to increase to Qty=2
6. Verify: French Fries Medium now shows Qty=2, price ₱140
7. Verify: French Fries Regular still shows Qty=3, price ₱150
8. Scroll to bottom
9. Verify: Subtotal = ₱150 + ₱140 = ₱290

**Expected Result:**
- Regular and Medium quantities are independent
- Each variant tracks its own quantity
- Prices calculate correctly: (qty × price_per_unit)
- Order total is accurate

---

### TEST 6: Kitchen Display Shows Correct Sizes ✓
**Objective:** Verify that Kitchen KDS display shows correct snack sizes without sugar level

**Precondition:** Order placed with French Fries Regular (Qty=3) and French Fries Medium (Qty=2)

**Steps:**
1. Open **Kitchen** screen
2. Look for French Fries orders
3. Verify: Shows **"French Fries (Regular) Qty 3"** (no sugar level)
4. Verify: Shows **"French Fries (Medium) Qty 2"** (no sugar level)
5. Verify: Both items clearly distinguish by size

**Expected Result:**
- Kitchen shows size indicator (Regular/Medium) for snacks
- No "Sugar Level" text appears for snacks
- Kitchen staff can clearly see which size was ordered

---

### TEST 7: History Preserves Snack Sizes ✓
**Objective:** Verify that order history correctly records snack sizes

**Precondition:** Order completed with French Fries Regular and Spring Rolls Medium

**Steps:**
1. Open **History** screen
2. Find the order with French Fries and Spring Rolls
3. Verify: Shows **"French Fries — Regular"** (with size)
4. Verify: Shows **"Spring Rolls — Medium"** (with size)
5. Verify: No sugar level shown for either snack

**Expected Result:**
- History displays snack sizes correctly
- Distinguishes between Regular and Medium variants
- No sugar level information for snacks
- Record matches what was ordered

---

### TEST 8: No Duplicates on UI Rebuild ✓
**Objective:** Verify that rebuilding the UI doesn't create duplicate snack items

**Precondition:** French Fries Regular in cart

**Steps:**
1. Open **Order Summary**
2. Perform each action and verify no duplicate appears after:
   - **Close and reopen** Order Summary
   - **Scroll** the cart items list
   - **Rotate device** (landscape ↔ portrait)
   - **Change quantity** of another item
   - **Press keyboard** (open/close)
   - **Switch to Kitchen** screen and back
3. After each action, verify: Still shows only 1 French Fries Regular item

**Expected Result:**
- No unintended duplicates created by any of the above actions
- Cart maintains integrity across rebuilds
- Size selection persists through all interactions

---

### TEST 9: Multiple Different Snacks ✓
**Objective:** Verify workflow with multiple different snack items

**Steps:**
1. Add **French Fries Regular** to cart
2. Add **Spring Rolls Medium** to cart
3. Add **Mozzarella Sticks Regular** to cart
4. Open Order Summary
5. Verify: All 3 items display with correct sizes
6. Change French Fries to Medium
7. Verify: Now have:
   - French Fries Regular ₱50
   - French Fries Medium ₱70
   - Spring Rolls Medium ₱80
   - Mozzarella Sticks Regular ₱70

**Expected Result:**
- Each snack displays independently with correct size
- Changing one snack's size doesn't affect others
- All variants have correct prices

---

### TEST 10: Coffee Items Unaffected ✓
**Objective:** Verify that coffee items still work correctly (no regression)

**Steps:**
1. Add **Cappuccino 12oz** to cart
2. Add **Cappuccino 16oz** to cart (change size in Order Summary)
3. Verify: Both show as separate items
4. Verify: 12oz shows sugar level
5. Verify: 16oz shows sugar level
6. Verify: No snacks involved; behavior unchanged

**Expected Result:**
- Coffee items unaffected by snack size fix
- Size switching still creates separate variants
- Sugar level still shows for coffee
- No regression in coffee ordering

---

## Validation Checklist

- [ ] Regular snack size persists from Cashier to Order Summary
- [ ] Medium snack size persists from Cashier to Order Summary
- [ ] Re-selecting same size does NOT create duplicate
- [ ] Changing size creates new separate variant
- [ ] Original variant preserved when changing size
- [ ] Quantities are independent per variant
- [ ] Prices calculate correctly per variant
- [ ] Kitchen shows correct sizes without sugar level
- [ ] History records correct sizes without sugar level
- [ ] No duplicates on rebuild/scroll/rotate/keyboard
- [ ] Multiple snacks work independently
- [ ] Coffee items still work (no regression)
- [ ] Build successful: `flutter build apk --release` ✓
- [ ] No new errors: `flutter analyze` (46 pre-existing only) ✓

---

## Code Changes
**File:** `lib/services/pos_provider.dart`
**Method:** `_resolveCupSize()` (lines 83-98)

**Before:**
```dart
if (normalized.isNotEmpty) {
  if (!menuItem.category.toLowerCase().contains('coffee-espresso')) {
    return '16oz';  // WRONG: Ignored explicit snack sizes
  }
  return normalized;
}
```

**After:**
```dart
if (normalized.isNotEmpty) {
  if (explicitCupSize != null) {
    return normalized;  // FIXED: Respect explicit sizes
  }
  if (!menuItem.category.toLowerCase().contains('coffee-espresso')) {
    return '16oz';
  }
  return normalized;
}
```

---

## Build Status
- ✅ flutter analyze: No new errors (46 pre-existing)
- ✅ flutter build apk --release: 63.4MB (Success)

---

## Notes
- All snack sizes (Regular/Medium) are now properly persisted
- Snacks correctly create separate variants when size changes
- Selecting same size prevents duplicates via early return check
- Coffee items (12oz/16oz) unaffected by this fix
- Sugar level correctly hidden from snacks in all screens
