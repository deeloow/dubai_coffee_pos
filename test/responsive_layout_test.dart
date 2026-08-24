import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dubai_coffee_pos/core/responsive.dart';

void main() {
  test('treats large tablet sizes as tablet and scales spacing', () {
    final tabletLayout = ResponsiveLayout.fromSize(const Size(1024, 768));
    final phoneLayout = ResponsiveLayout.fromSize(const Size(390, 844));

    expect(tabletLayout.isTablet, isTrue);
    expect(phoneLayout.isTablet, isFalse);
    expect(tabletLayout.scale, greaterThan(1.0));
    expect(tabletLayout.contentMaxWidth, greaterThan(phoneLayout.contentMaxWidth));
  });

  test('classifies compact phones and wide tablets for adaptive layouts', () {
    final compactPhone = ResponsiveLayout.fromSize(const Size(360, 640));
    final wideTablet = ResponsiveLayout.fromSize(const Size(1366, 1024));

    expect(compactPhone.isCompactPhone, isTrue);
    expect(compactPhone.isWideScreen, isFalse);
    expect(wideTablet.isTablet, isTrue);
    expect(wideTablet.isWideScreen, isTrue);
  });
}
