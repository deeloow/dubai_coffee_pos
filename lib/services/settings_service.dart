import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class SettingsService {
  final Box _settings = Hive.box('settings');

  static const String _qrCodePathKey = 'paymentQrCodePath';
  static const String _qrCodeBase64Key = 'paymentQrCodeBase64';
  static const String _qrCodeMimeTypeKey = 'paymentQrCodeMimeType';
  static const String _gcashNumberKey = 'gcashNumber';

  String? get paymentQrCodePath => _settings.get(_qrCodePathKey) as String?;
  String? get paymentQrCodeBase64 => _settings.get(_qrCodeBase64Key) as String?;
  String? get paymentQrCodeMimeType =>
      _settings.get(_qrCodeMimeTypeKey) as String?;
  String? get gcashNumber => _settings.get(_gcashNumberKey) as String?;

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
      final bytes = await source.readAsBytes();
      final extension = source.path.contains('.')
          ? source.path.substring(source.path.lastIndexOf('.'))
          : '.png';
      return savePaymentQrCodeBytes(bytes, extension: extension);
    } catch (_) {
      return null;
    }
  }

  Future<String?> savePaymentQrCodeBytes(
    List<int> bytes, {
    String? extension,
    String? mimeType,
  }) async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final fileExtension =
          extension != null && extension.isNotEmpty ? extension : '.png';
      final target = File('${supportDir.path}/payment_qr$fileExtension');
      await target.create(recursive: true);
      await target.writeAsBytes(bytes);
      await _settings.put(_qrCodePathKey, target.path);
      await _settings.put(_qrCodeBase64Key, base64Encode(bytes));
      await _settings.put(_qrCodeMimeTypeKey, mimeType ?? 'image/png');
      return target.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> applyRemoteQrState(
      {String? path, String? base64, String? mimeType, String? gcashNumber}) async {
    if (base64 != null && base64.isNotEmpty) {
      final bytes = base64Decode(base64);
      final targetPath = path != null && path.isNotEmpty
          ? path
          : await savePaymentQrCodeBytes(bytes, mimeType: mimeType);
      if (targetPath != null) {
        final target = File(targetPath);
        if (!target.parent.existsSync()) {
          await target.parent.create(recursive: true);
        }
        await target.create(recursive: true);
        await target.writeAsBytes(bytes);
        await _settings.put(_qrCodePathKey, target.path);
        await _settings.put(_qrCodeBase64Key, base64Encode(bytes));
        await _settings.put(_qrCodeMimeTypeKey, mimeType ?? 'image/png');
      }
      await saveGcashNumber(gcashNumber);
      return;
    }

    await saveGcashNumber(gcashNumber);
    await clearPaymentQrCode();
  }

  Future<void> saveGcashNumber(String? number) async {
    if (number == null || number.trim().isEmpty) {
      await _settings.delete(_gcashNumberKey);
      return;
    }
    await _settings.put(_gcashNumberKey, number.trim());
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
    await _settings.delete(_qrCodeBase64Key);
    await _settings.delete(_qrCodeMimeTypeKey);
  }
}
