import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/local_order_socket_provider.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class AdminQrScreen extends StatefulWidget {
  const AdminQrScreen({super.key});

  @override
  State<AdminQrScreen> createState() => _AdminQrScreenState();
}

class _AdminQrScreenState extends State<AdminQrScreen> {
  final SettingsService _settingsService = SettingsService();
  File? _qrFile;
  bool _uploading = false;
  final TextEditingController _gcashNumberCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadQrFile();
    _gcashNumberCtrl.text = _settingsService.gcashNumber ?? '';
  }

  Future<void> _loadQrFile() async {
    final file = await _settingsService.loadPaymentQrCodeFile();
    setState(() {
      _qrFile = file;
    });
  }

  Future<void> _pickQrFile() async {
    setState(() {
      _uploading = true;
    });

    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (!mounted) return;
    if (result == null || result.files.isEmpty) {
      setState(() => _uploading = false);
      return;
    }

    final rawPath = result.files.single.path;
    if (rawPath == null) {
      setState(() => _uploading = false);
      return;
    }

    final sourceFile = File(rawPath);
    final savedPath = await _settingsService.savePaymentQrCode(sourceFile);
    if (!mounted) return;
    if (savedPath != null) {
      _qrFile = File(savedPath);
      final socketProvider = context.read<LocalOrderSocketProvider>();
      if (socketProvider.isConnected) {
        await socketProvider.sendQrSync(
          path: savedPath,
          base64: _settingsService.paymentQrCodeBase64,
          mimeType: _settingsService.paymentQrCodeMimeType,
          gcashNumber: _settingsService.gcashNumber,
        );
      }
    }

    setState(() {
      _uploading = false;
    });
  }

  Future<void> _clearQr() async {
    await _settingsService.clearPaymentQrCode();
    if (!mounted) return;
    final socketProvider = context.read<LocalOrderSocketProvider>();
    if (socketProvider.isConnected) {
      await socketProvider.sendQrSync(
        gcashNumber: _settingsService.gcashNumber,
      );
    }
    setState(() {
      _qrFile = null;
    });
  }

  @override
  void dispose() {
    _gcashNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncGcashSettings() async {
    final socketProvider = context.read<LocalOrderSocketProvider>();
    final number = _gcashNumberCtrl.text.trim();
    await _settingsService.saveGcashNumber(number.isEmpty ? null : number);
    if (socketProvider.isConnected) {
      await socketProvider.sendQrSync(
        path: _settingsService.paymentQrCodePath,
        base64: _settingsService.paymentQrCodeBase64,
        mimeType: _settingsService.paymentQrCodeMimeType,
        gcashNumber: _settingsService.gcashNumber,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Payment QR Code'),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText('GCash Settings',
                    size: 14, weight: FontWeight.w600),
                const SizedBox(height: 12),
                TextField(
                  controller: _gcashNumberCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'GCash Number',
                    hintText: '09XX',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _syncGcashSettings(),
                ),
                const SizedBox(height: 16),
                const AppText('Current QR Code',
                    size: 14, weight: FontWeight.w600),
                const SizedBox(height: 12),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 280,
                      maxHeight: 280,
                    ),
                    child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.borderColor, width: 0.5),
                    ),
                    child: _qrFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              _qrFile!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              alignment: Alignment.center,
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.qr_code,
                                size: 96, color: AppColors.espresso),
                          ),
                  ),
                ),
                  ),
                ),
                const SizedBox(height: 16),
                AppText(
                  _qrFile != null
                      ? 'The selected QR code will be shown to customers during QR payment.'
                      : 'No QR code configured yet. Upload an image to use a custom payment QR code.',
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _uploading ? null : _pickQrFile,
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                            _uploading ? 'Uploading...' : 'Upload QR Code'),
                      ),
                    ),
                  ],
                ),
                if (_qrFile != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _clearQr,
                    icon:
                        const Icon(Icons.delete_outline, color: AppColors.red),
                    label: const Text('Remove QR Code',
                        style: TextStyle(color: AppColors.red)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
