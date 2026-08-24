# Snack Size Persistence - Visual Flow Diagram

## Problem Flow (BEFORE FIX)

```
USER IN CASHIER
    ↓
[Select French Fries from Snacks]
    ↓
[Size Picker appears: Regular | Medium]
    ↓
[Click: Regular]
    ↓
addItemWithCupSize(menuItem, "Regular") ← Size passed explicitly
    ↓
_resolveCupSize(menuItem, explicitCupSize="Regular")
    ↓
OLD LOGIC:
  if (!category.contains('coffee-espresso'))
    return '16oz'  ← BUG: Ignores "Regular"!
    ↓
Item stored with cupSize='16oz' ✗ WRONG SIZE!
    ↓
USER OPENS ORDER SUMMARY
    ↓
[French Fries item displays]
    ↓
Check size buttons:
  - Regular button: "selected = (item.cupSize == 'Regular')"  
    → "selected = ('16oz' == 'Regular')"  
    → FALSE ✗ Button NOT highlighted
  - Medium button: "selected = (item.cupSize == 'Medium')"
    → "selected = ('16oz' == 'Medium')"
    → FALSE ✗ Button NOT highlighted
    ↓
NO SIZE SHOWS AS SELECTED!
User forced to select size again
    ↓
[Click: Regular button]
    ↓
setItemCupSize(index, "Regular", price)
    ↓
current.cupSize='16oz' != normalizedCupSize='Regular'
    ↓
No early return → Logic continues
    ↓
existingIndex = indexWhere(menuItemId + "Regular") → -1 (not found)
    ↓
isSnack=true → Creates NEW OrderItem
    ↓
DUPLICATE CREATED! ✗
Now have:
  - French Fries (cupSize='16oz')
  - French Fries (cupSize='Regular')
```

---

## Solution Flow (AFTER FIX)

```
USER IN CASHIER
    ↓
[Select French Fries from Snacks]
    ↓
[Size Picker appears: Regular | Medium]
    ↓
[Click: Regular]
    ↓
addItemWithCupSize(menuItem, "Regular") ← Size passed explicitly
    ↓
_resolveCupSize(menuItem, explicitCupSize="Regular")
    ↓
NEW LOGIC:
  if (explicitCupSize != null)
    return "Regular"  ← FIXED: Uses explicit size!
    ↓
_resolvePrice(menuItem, "Regular")
    ↓
MenuService.priceForCupSize() → ₱50
    ↓
Item stored with:
  cupSize='Regular' ✓ CORRECT!
  price=₱50 ✓ CORRECT!
    ↓
USER OPENS ORDER SUMMARY
    ↓
[French Fries item displays]
    ↓
Check size buttons:
  - Regular button: "selected = (item.cupSize == 'Regular')"
    → "selected = ('Regular' == 'Regular')"
    → TRUE ✓ Button HIGHLIGHTED!
  - Medium button: "selected = (item.cupSize == 'Medium')"
    → "selected = ('Regular' == 'Medium')"
    → FALSE ✓ Button NOT highlighted
    ↓
REGULAR SIZE SHOWS SELECTED! ✓
User can see: French Fries with Regular already chosen
    ↓
SCENARIO 1: [Click: Regular button again]
    ↓
setItemCupSize(index, "Regular", price)
    ↓
normalizedCupSize = "Regular"
current.cupSize = "Regular"
    ↓
if (current.cupSize == normalizedCupSize)
  return  ← EARLY RETURN! ✓
    ↓
NO DUPLICATE CREATED! ✓
Still shows only 1 French Fries Regular
    ↓
---
SCENARIO 2: [Click: Medium button]
    ↓
setItemCupSize(index, "Medium", price)
    ↓
normalizedCupSize = "Medium"
current.cupSize = "Regular"
    ↓
if (current.cupSize == normalizedCupSize)
  return  ← NO EARLY RETURN (different size)
    ↓
existingIndex = indexWhere(menuItemId + "Medium") → -1 (not found)
    ↓
isSnack=true → Creates NEW OrderItem
    ↓
SEPARATE VARIANT CREATED ✓
Now correctly have:
  - French Fries (cupSize='Regular', qty=1, price=₱50)
  - French Fries (cupSize='Medium', qty=1, price=₱70)
```

---

## Data Structure After Fix

### Cashier → Add French Fries Regular

```
addItemWithCupSize called with:
  menuItem: French Fries
  cupSize: "Regular"
  
_items array now contains:
{
  menuItemId: "snack_001",
  name: "French Fries",
  cupSize: "Regular",        ← FIXED: Properly preserved!
  price: ₱50,               ← FIXED: Correct price!
  icon: <icon>,
  sugarLevel: "",           ← Snacks have no sugar
  qty: 1
}
```

### Order Summary → Display Item

```
Order Summary receives item:
  cupSize = "Regular"

Size button rendering:
  for size in ['Regular', 'Medium']:
    selected = (item.cupSize == size)
    
  Regular: selected = ('Regular' == 'Regular') = TRUE ✓
  Medium: selected = ('Regular' == 'Medium') = FALSE ✓

Result: Regular button is HIGHLIGHTED/SELECTED ✓
```

### Order Summary → Click Regular Again

```
setItemCupSize called with:
  index: 0
  menuItemId: "snack_001"
  cupSize: "Regular"
  price: ₱50

Logic:
  current = _items[0]  // {cupSize: "Regular"}
  normalizedCupSize = "Regular"
  
  if (current.cupSize == normalizedCupSize)
    return  ← EARLY RETURN!
    
Result: NO duplicate created! ✓
Still 1 item in cart
```

### Order Summary → Click Medium Button

```
setItemCupSize called with:
  index: 0
  menuItemId: "snack_001"
  cupSize: "Medium"
  price: ₱70

Logic:
  current = _items[0]  // {cupSize: "Regular"}
  normalizedCupSize = "Medium"
  
  if (current.cupSize == normalizedCupSize)
    return  ← NO RETURN (different size)
    
  existingIndex = _items.indexWhere(
    (i) => i.menuItemId == "snack_001" && i.cupSize == "Medium"
  )  → -1 (not found)
  
  isSnack = true  (Medium contains "medium")
  
  Add NEW OrderItem:
  {
    menuItemId: "snack_001",
    name: "French Fries",
    cupSize: "Medium",    ← NEW VARIANT
    price: ₱70,
    icon: <icon>,
    sugarLevel: "",
    qty: 1
  }

Result: 2 items in cart ✓
  [0] French Fries Regular ₱50 Qty 1
  [1] French Fries Medium  ₱70 Qty 1
```

---

## Key Differences

| Aspect | BEFORE (Bug) | AFTER (Fixed) |
|--------|------------|---------------|
| Snack size in Cashier | "Regular" passed | "Regular" passed |
| `_resolveCupSize()` behavior | Ignored it, returned '16oz' | **Respected it, returned "Regular"** |
| Size stored in item | '16oz' ✗ | 'Regular' ✓ |
| Order Summary display | No size highlighted | **Regular button highlighted** ✓ |
| Clicking same size | Created duplicate ✗ | **Early return, no duplicate** ✓ |
| Clicking different size | Didn't work properly | **Created separate variant** ✓ |

---

## Conclusion

The fix is minimal but critical:
- **Change:** Added `if (explicitCupSize != null)` check to respect explicit sizes
- **Impact:** Snack sizes now properly persist from Cashier → Order Summary
- **Result:** 
  - ✓ No duplicates when selecting same size
  - ✓ Correct variants when changing size
  - ✓ Independent quantity/price tracking
  - ✓ Correct display in Kitchen and History
