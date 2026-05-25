import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ─── App Text ─────────────────────────────────────────────────────────────────

class AppText extends StatelessWidget {
  final String text;
  final double? size;
  final FontWeight? weight;
  final Color? color;
  final TextAlign? align;
  final int? maxLines;
  final TextOverflow? overflow;

  const AppText(this.text,
      {super.key,
      this.size,
      this.weight,
      this.color,
      this.align,
      this.maxLines,
      this.overflow});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        textAlign: align,
        softWrap: true,
        maxLines: maxLines,
        overflow: overflow,
        style: GoogleFonts.dmSans(
          fontSize: size ?? 13,
          fontWeight: weight ?? FontWeight.normal,
          color: color ?? AppColors.espresso,
        ));
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;

  const SectionCard({super.key, required this.child, this.padding, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      padding: padding ?? const EdgeInsets.all(12),
      child: child,
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool gold;
  final String? delta;
  final bool deltaUp;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.gold = false,
    this.delta,
    this.deltaUp = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(label, size: 11, color: AppColors.textMuted),
          const SizedBox(height: 4),
          AppText(value,
              size: 18,
              weight: FontWeight.w600,
              color: gold ? AppColors.goldDark : AppColors.espresso),
          if (delta != null) ...[
            const SizedBox(height: 2),
            AppText(delta!,
                size: 10,
                color: deltaUp ? AppColors.green : AppColors.red),
          ]
        ],
      ),
    );
  }
}

// ─── Gold Button ──────────────────────────────────────────────────────────────

class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool outlined;
  final bool danger;

  const GoldButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.outlined = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFFFCEBEB)
        : outlined
            ? AppColors.cream
            : AppColors.espresso;
    final fg = danger
        ? AppColors.red
        : outlined
            ? AppColors.espresso
            : AppColors.goldLight;
    final border = danger
        ? AppColors.red.withOpacity(0.4)
        : outlined
            ? AppColors.borderColor
            : AppColors.espresso;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            AppText(label, size: 13, weight: FontWeight.w600, color: fg),
          ],
        ),
      ),
    );
  }
}

// ─── Pay Method Button ────────────────────────────────────────────────────────

class PayMethodButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const PayMethodButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.espresso : AppColors.cream,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isPrimary ? AppColors.espresso : AppColors.borderColor,
              width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color: isPrimary ? AppColors.goldLight : AppColors.espresso),
            const SizedBox(height: 4),
            AppText(label,
                size: 12,
                weight: FontWeight.w500,
                color: isPrimary ? AppColors.goldLight : AppColors.espresso),
          ],
        ),
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String label;
  final bool isPaid;

  const StatusBadge({super.key, required this.label, required this.isPaid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPaid
            ? const Color(0xFFEAF3DE)
            : const Color(0xFFFCEBEB),
        borderRadius: BorderRadius.circular(4),
      ),
      child: AppText(label,
          size: 10,
          weight: FontWeight.w600,
          color: isPaid ? AppColors.green : AppColors.red),
    );
  }
}

// ─── Input Field ──────────────────────────────────────────────────────────────

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final Widget? prefix;
  final int? maxLines;
  final void Function(String)? onChanged;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffix,
    this.prefix,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      onChanged: onChanged,
      style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.espresso),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        prefixIcon: prefix,
      ),
    );
  }
}

// ─── Divider Row ──────────────────────────────────────────────────────────────

class DividerRow extends StatelessWidget {
  final String left;
  final String right;
  final bool isTotal;
  final bool isDiscount;

  const DividerRow({
    super.key,
    required this.left,
    required this.right,
    this.isTotal = false,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTotal ? 6 : 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppText(left,
              size: isTotal ? 15 : 12,
              weight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isDiscount ? AppColors.green : AppColors.textBrown),
          AppText(right,
              size: isTotal ? 15 : 12,
              weight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal
                  ? AppColors.goldDark
                  : isDiscount
                      ? AppColors.green
                      : AppColors.textBrown),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyState({super.key, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.borderColor),
          const SizedBox(height: 12),
          AppText(message, size: 13, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

// ─── Loading Overlay ──────────────────────────────────────────────────────────

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
        ),
      ),
    );
  }
}

String formatPHP(double amount) =>
    '₱${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
