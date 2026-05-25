import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/pos_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class CustomerNameSheet extends StatefulWidget {
  const CustomerNameSheet({super.key});

  @override
  State<CustomerNameSheet> createState() => _CustomerNameSheetState();
}

class _CustomerNameSheetState extends State<CustomerNameSheet> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final existing = context.read<PosProvider>().customerName;
    if (existing.isNotEmpty) _ctrl.text = existing;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    context.read<PosProvider>().setCustomerName(_ctrl.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bgLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('👤',
                      style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText('Customer Name',
                        size: 16, weight: FontWeight.w600),
                    AppText('Required before taking order',
                        size: 12, color: AppColors.textMuted),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            TextFormField(
              controller: _ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(
                  fontSize: 18, color: AppColors.espresso),
              decoration: InputDecoration(
                hintText: 'e.g. Juan dela Cruz',
                hintStyle: TextStyle(
                    fontSize: 18,
                    color: AppColors.textMuted.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.person_outline,
                    color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.cream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.gold, width: 1.5),
                ),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty
                      ? 'Customer name is required'
                      : null,
              onFieldSubmitted: (_) => _confirm(),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.borderColor),
                      foregroundColor: AppColors.espresso,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.espresso,
                      foregroundColor: AppColors.goldLight,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Confirm & Start Order'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
