import 'package:flutter/widgets.dart';

class ResponsiveLayout {
  const ResponsiveLayout({
    required this.screenSize,
    required this.isTablet,
    required this.scale,
    required this.contentMaxWidth,
    required this.isLandscape,
    required this.isCompactPhone,
    required this.isWideScreen,
  });

  final Size screenSize;
  final bool isTablet;
  final double scale;
  final double contentMaxWidth;
  final bool isLandscape;
  final bool isCompactPhone;
  final bool isWideScreen;

  factory ResponsiveLayout.fromSize(Size size) {
    final isLandscape = size.width >= size.height;
    final shortestSide = size.shortestSide;
    final isTablet = shortestSide >= 700;
    final isCompactPhone = shortestSide < 600 && !isTablet;
    final isWideScreen = size.width >= 900 || (isLandscape && size.width >= 700);
    final baseScale = isTablet
        ? (shortestSide >= 900 ? 1.12 : 1.06)
        : (isCompactPhone ? 0.96 : 1.0);
    final contentMaxWidth = isTablet
        ? (isLandscape ? 1200.0 : 900.0)
        : (isWideScreen ? 860.0 : 800.0);

    return ResponsiveLayout(
      screenSize: size,
      isTablet: isTablet,
      scale: baseScale,
      contentMaxWidth: contentMaxWidth,
      isLandscape: isLandscape,
      isCompactPhone: isCompactPhone,
      isWideScreen: isWideScreen,
    );
  }

  double scaled(double value) => value * scale;

  double scaledHorizontal(double value) => value * (isTablet ? 1.04 : 1.0);

  EdgeInsetsGeometry scaledPadding(EdgeInsetsGeometry value) {
    if (value is EdgeInsets) {
      return value * scale;
    }
    return value;
  }

  static ResponsiveLayout of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ResponsiveLayout.fromSize(size);
  }
}
