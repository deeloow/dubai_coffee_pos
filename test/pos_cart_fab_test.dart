import 'package:flutter_test/flutter_test.dart';
import 'package:dubai_coffee_pos/screens/pos/pos_screen.dart';

void main() {
  test('hides the cart FAB in landscape mode while keeping it in portrait', () {
    expect(shouldShowCartFab(isLandscape: false, hasItems: true), isTrue);
    expect(shouldShowCartFab(isLandscape: true, hasItems: true), isFalse);
    expect(shouldShowCartFab(isLandscape: false, hasItems: false), isFalse);
  });
}
