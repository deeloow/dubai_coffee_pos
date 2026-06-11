import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class SettingsService {
  final Box _settings = Hive.box('settings');

  static const String _qrCodePathKey = 'paymentQrCodePath';

  String? get paymentQrCodePath => _settings.get(_qrCodePathKey) as String?;

  Future<File?> loadPaymentQrCodeFile() async {
    final path = paymentQrCodePath;
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  Future<String?> savePaymentQrCode(File source) async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final extension = source.path.contains('.')
          ? source.path.substring(source.path.lastIndexOf('.'))
          : '.png';
      final target = File('${supportDir.path}/payment_qr$extension');
      await target.create(recursive: true);
      await target.writeAsBytes(await source.readAsBytes());
      await _settings.put(_qrCodePathKey, target.path);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPaymentQrCode() async {
    final path = paymentQrCodePath;
    if (path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (_) {}
    }
    await _settings.delete(_qrCodePathKey);
  }
}
