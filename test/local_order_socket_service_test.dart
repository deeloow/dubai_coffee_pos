import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/services/local_order_socket_service.dart';
import 'package:dubai_coffee_pos/services/menu_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tmp = await Directory.systemTemp.createTemp('hive_local_socket_test_');
    Hive.init(tmp.path);
    for (final name in ['settings', 'reports_history', 'orders', 'recipes', 'inventory', 'menu', 'menu_categories']) {
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {}
      await Hive.openBox(name);
    }
  });

  tearDown(() async {
    final service = LocalOrderSocketService();
    try {
      await service.disconnect();
    } catch (_) {}
    try {
      await service.stopServer();
    } catch (_) {}
    for (final name in ['settings', 'reports_history', 'orders', 'recipes', 'inventory', 'menu', 'menu_categories']) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).clear();
      }
    }
  });

  test('admin broadcasts report state after barista completed order', () async {
    final service = LocalOrderSocketService();
    await service.stopServer();
    await service.disconnect();
    await service.startServer(port: 0);

    final port = service.port;
    const host = '127.0.0.1';
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));

    final messages = <Map<String, dynamic>>[];
    final buffer = StringBuffer();
    final reportStateCompleter = Completer<void>();

    socket.listen(
      (data) {
        buffer.write(utf8.decode(data));
        var content = buffer.toString();
        while (content.contains('\n')) {
          final index = content.indexOf('\n');
          final raw = content.substring(0, index).trim();
          content = content.substring(index + 1);
          if (raw.isEmpty) {
            continue;
          }
          try {
            final payload = jsonDecode(raw);
            if (payload is Map<String, dynamic>) {
              messages.add(payload);
            }
          } catch (_) {
            // ignore parse failures in this test
          }
        }
        buffer.clear();
        buffer.write(content);

        final hasReportState = messages.any((m) => m['type'] == 'report_state');
        final hasMonthlyReportState = messages.any((m) => m['type'] == 'monthly_report_state');
        if (hasReportState && hasMonthlyReportState && !reportStateCompleter.isCompleted) {
          reportStateCompleter.complete();
        }
      },
      onError: (error) {
        if (!reportStateCompleter.isCompleted) {
          reportStateCompleter.completeError(error);
        }
      },
      onDone: () {
        if (!reportStateCompleter.isCompleted) {
          reportStateCompleter.complete();
        }
      },
    );

    socket.write(jsonEncode({'type': 'hello'}) + '\n');
    await socket.flush();

    await Future.wait([
      reportStateCompleter.future,
      Future.delayed(const Duration(milliseconds: 300)),
    ]);

    final order = Order(
      id: 'test-order-1',
      orderNumber: 1,
      customerName: 'Test Customer',
      cashierName: 'Admin',
      items: [
        OrderItem(
          menuItemId: 'item-1',
          name: 'Matcha',
          price: 120,
          icon: '🍵',
          qty: 2,
          sugarLevel: 'Regular sugar',
          cupSize: '12oz',
        ),
      ],
      subtotal: 240,
      discount: 0,
      discountLabel: '',
      total: 240,
      tendered: 240,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime.now(),
      status: OrderStatus.completed,
    );

    socket.write(jsonEncode({'type': 'order', 'payload': order.toMap()}) + '\n');
    await socket.flush();

    await reportStateCompleter.future.timeout(const Duration(seconds: 5));

    expect(messages.any((m) => m['type'] == 'report_state'), isTrue);
    expect(messages.any((m) => m['type'] == 'monthly_report_state'), isTrue);

    await socket.close();
    await service.stopServer();
  });

  test('starting an already-running server keeps existing clients connected', () async {
    final service = LocalOrderSocketService();
    await service.stopServer();
    await service.disconnect();
    await service.startServer(port: 0);

    final originalPort = service.port;
    final clientSocket = await Socket.connect('127.0.0.1', originalPort, timeout: const Duration(seconds: 5));

    final clientClosed = Completer<void>();
    clientSocket.done.then((_) {
      if (!clientClosed.isCompleted) {
        clientClosed.complete();
      }
    });

    await service.startServer(port: originalPort);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(service.isConnected, isTrue,
        reason: 'An already-running socket server should keep its existing client connection alive.');
    expect(clientClosed.isCompleted, isFalse,
        reason: 'An already-running socket server should not tear down existing client connections when restarted.');

    await clientSocket.close();
    await service.stopServer();
  });

  test('menu sync updates persisted drink pricing on server side', () async {
    final service = LocalOrderSocketService();
    await service.stopServer();
    await service.disconnect();
    await service.startServer(port: 0);

    final port = service.port;
    const host = '127.0.0.1';
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));

    final messages = <Map<String, dynamic>>[];
    final buffer = StringBuffer();
    final handshakeCompleter = Completer<void>();
    final initialSyncCompleter = Completer<void>();

    void checkInitialSyncComplete() {
      final requiredTypes = {'report_state', 'monthly_report_state', 'inventory_sync', 'menu_sync', 'qr_sync'};
      final receivedTypes = messages.map((m) => m['type']?.toString()).whereType<String>().toSet();
      if (requiredTypes.difference(receivedTypes).isEmpty && !initialSyncCompleter.isCompleted) {
        initialSyncCompleter.complete();
      }
    }

    socket.listen(
      (data) {
        buffer.write(utf8.decode(data));
        var content = buffer.toString();
        while (content.contains('\n')) {
          final index = content.indexOf('\n');
          final raw = content.substring(0, index).trim();
          content = content.substring(index + 1);
          if (raw.isEmpty) {
            continue;
          }
          try {
            final payload = jsonDecode(raw);
            if (payload is Map<String, dynamic>) {
              messages.add(payload);
            }
          } catch (_) {
            // ignore parse failures in this test
          }
        }
        buffer.clear();
        buffer.write(content);

        if (messages.any((m) => m['type'] == 'welcome') && !handshakeCompleter.isCompleted) {
          handshakeCompleter.complete();
        }
        checkInitialSyncComplete();
      },
      onError: (error) {
        if (!handshakeCompleter.isCompleted) {
          handshakeCompleter.completeError(error);
        }
      },
      onDone: () {
        if (!handshakeCompleter.isCompleted) {
          handshakeCompleter.complete();
        }
      },
    );

    socket.write(jsonEncode({'type': 'hello'}) + '\n');
    await socket.flush();
    await handshakeCompleter.future.timeout(const Duration(seconds: 5));

    checkInitialSyncComplete();

    // Wait for the server's initial sync payloads to complete before sending our menu update.
    await initialSyncCompleter.future.timeout(const Duration(seconds: 5));
    final initialMenuSync = messages.firstWhere((message) => message['type'] == 'menu_sync');
    expect(initialMenuSync['payload']['categories'], isA<List>());

    final menuItem = {
      'id': 'coffee-sync-1',
      'name': 'Cinnamon Latte',
      'price': 60,
      'icon': '☕',
      'category': 'Coffee-espresso base',
      'badge': '',
      'cupSize': '12oz',
      'availableCupSizes': ['12oz', '16oz'],
      'priceByCupSize': {'12oz': 65.0, '16oz': 85.0},
      'imagePath': 'assets/icon.png',
      'imageBase64': null,
      'imageMimeType': null,
      'available': true,
    };

    socket.write(jsonEncode({
      'type': 'menu_sync',
      'payload': {
        'items': [menuItem],
        'categories': [
          {
            'id': 'category-coffee',
            'name': 'Coffee-espresso base',
            'cupSizeType': 'TWELVE_AND_SIXTEEN',
          },
        ],
      },
    }) + '\n');
    await socket.flush();

    final menuService = MenuService();
    final timeoutAt = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(timeoutAt)) {
      final persistedItem = menuService.getMenuItemById('coffee-sync-1');
      if (persistedItem != null) {
        expect(persistedItem.priceByCupSize['12oz'], 65.0);
        expect(persistedItem.priceByCupSize['16oz'], 85.0);
        expect(await menuService.resolveCategoryIdByName('Coffee-espresso base'), 'category-coffee');
        expect(
          await menuService.categoryCupSizeType('Coffee-espresso base'),
          CategoryCupSizeType.twelveAndSixteen,
        );
        await socket.close();
        await service.stopServer();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    await socket.close();
    await service.stopServer();
    fail('Menu item was not synced to the server within the expected time.');
  });
}
