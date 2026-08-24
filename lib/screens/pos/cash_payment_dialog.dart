import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class CashPaymentDialog extends StatefulWidget {
  final double total;
  final Future<void> Function(double tendered, double change) onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onClose;

  const CashPaymentDialog({
    super.key,
    required this.total,
    required this.onConfirm,
    required this.onCancel,
    required this.onClose,
  });

  @override
  State<CashPaymentDialog> createState() => _CashPaymentDialogState();
}

class _CashPaymentDialogState extends State<CashPaymentDialog> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tendered = double.tryParse(_ctrl.text) ?? 0;
    final change = tendered - widget.total;

    return KeyboardSafeDialog(
      child: LayoutBuilder(
        builder: (layoutContext, constraints) {
          final dialogWidth =
              constraints.maxWidth > 720 ? 620.0 : constraints.maxWidth - 32;

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: dialogWidth),
            child: AlertDialog(
              scrollable: true,
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              insetPadding: EdgeInsets.zero,
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: DialogHeader(
                title: 'Cash Payment',
                titleSize: 16,
                titleWeight: FontWeight.w600,
                onClose: widget.onClose,
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const AppText('Amount due', size: 13),
                            AppText(formatPHP(widget.total),
                                size: 16,
                                weight: FontWeight.w700,
                                color: AppColors.goldDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        focusNode: _focusNode,
                        controller: _ctrl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.done,
                        scrollPadding: const EdgeInsets.only(bottom: 180),
                        style: const TextStyle(
                            fontSize: 20, color: AppColors.espresso),
                        decoration: const InputDecoration(
                          labelText: 'Cash tendered',
                          prefixText: '₱ ',
                          prefixStyle: TextStyle(
                              fontSize: 18, color: AppColors.espresso),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (tendered >= widget.total && tendered > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF3DE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const AppText('Change',
                                  size: 12, color: AppColors.green),
                              AppText(formatPHP(change),
                                  size: 22,
                                  weight: FontWeight.w700,
                                  color: AppColors.green),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const AppText('Cancel',
                      size: 13, color: AppColors.textMuted),
                ),
                ElevatedButton(
                  onPressed: tendered < widget.total
                      ? null
                      : () async {
                          await widget.onConfirm(tendered, change);
                        },
                  child: const Text('Confirm'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
