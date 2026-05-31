import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/models.dart';

class LocalOrderSocketService {
  final int defaultPort;
  ServerSocket? _serverSocket;
  Socket? _clientSocket;
  final List<Socket> _connectedClients = [];
  final Map<Socket, String> _receiveBuffers = {};
  final StreamController<Order> _receivedOrdersController = StreamController.broadcast();
  final StreamController<String> _statusController = StreamController.broadcast();
  final StreamController<List<String>> _peersController = StreamController.broadcast();
  final Duration _reconnectDelay = const Duration(seconds: 5);

  bool _autoReconnect = false;
  bool _disposed = false;
  String _host = '0.0.0.0';
  int _port = 4567;
  Timer? _reconnectTimer;

  LocalOrderSocketService({this.defaultPort = 4567}) {
    _port = defaultPort;
  }

  Stream<Order> get receivedOrders => _receivedOrdersController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<List<String>> get connectedPeers => _peersController.stream;
  String get localAddress => _host;
  int get port => _port;
  bool get isServerMode => _serverSocket != null;
  bool get isClientMode => _clientSocket != null;
  bool get isConnected =>
      isServerMode ? _connectedClients.isNotEmpty : _clientSocket != null;

  Future<void> startServer({int port = 4567}) async {
    await stopServer();
    await disconnect();
    _port = port;
    _autoReconnect = false;
    _host = await _fetchLocalIpAddress();
    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    _setStatus('listening');
    _updatePeers();
    _serverSocket!.listen(
      _handleNewClient,
      onError: (error) {
        _setStatus('error');
        _scheduleReconnectIfNeeded();
      },
    );
  }

  Future<void> stopServer() async {
    _autoReconnect = false;
    for (final socket in List<Socket>.from(_connectedClients)) {
      try {
        await socket.close();
      } catch (_) {}
      socket.destroy();
    }
    _connectedClients.clear();
    _receiveBuffers.clear();
    try {
      await _serverSocket?.close();
    } catch (_) {}
    _serverSocket = null;
    _setStatus('idle');
    _updatePeers();
  }

  Future<void> connectToHost(String host, {int port = 4567}) async {
    await disconnect();
    _autoReconnect = true;
    _host = host;
    _port = port;
    _setStatus('connecting');

    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      _clientSocket = socket;
      _setStatus('connected');
      _updatePeers();
      _receiveBuffers[socket] = '';
      socket.listen(
        (data) => _handleSocketData(socket, data),
        onDone: () {
          _clientSocket = null;
          _setStatus('disconnected');
          _updatePeers();
          _scheduleReconnectIfNeeded();
        },
        onError: (error) {
          _clientSocket = null;
          _setStatus('error');
          _updatePeers();
          _scheduleReconnectIfNeeded();
        },
        cancelOnError: true,
      );
    } catch (error) {
      _setStatus('error');
      _scheduleReconnectIfNeeded();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      await _clientSocket?.close();
    } catch (_) {}
    _clientSocket?.destroy();
    _clientSocket = null;
    _setStatus('idle');
    _updatePeers();
  }

  Future<bool> sendOrder(Order order) async {
    final payload = {
      'type': 'order',
      'payload': order.toMap(),
    };
    return sendJson(payload);
  }

  Future<bool> sendJson(Map<String, dynamic> jsonMap) async {
    if (isServerMode && _connectedClients.isNotEmpty) {
      final message = '${jsonEncode(jsonMap)}\n';
      for (final socket in List<Socket>.from(_connectedClients)) {
        try {
          socket.write(message);
          await socket.flush();
        } catch (error) {
          _removeClient(socket);
        }
      }
      return true;
    }

    if (isClientMode && _clientSocket != null) {
      try {
        _clientSocket!.write('${jsonEncode(jsonMap)}\n');
        await _clientSocket!.flush();
        return true;
      } catch (error) {
        _setStatus('error');
        _scheduleReconnectIfNeeded();
        return false;
      }
    }

    return false;
  }

  void _handleNewClient(Socket socket) {
    _connectedClients.add(socket);
    _receiveBuffers[socket] = '';
    _setStatus('connected');
    _updatePeers();
    socket.listen(
      (data) => _handleSocketData(socket, data),
      onDone: () {
        _removeClient(socket);
      },
      onError: (_) {
        _removeClient(socket);
      },
      cancelOnError: true,
    );
  }

  void _handleSocketData(Socket socket, List<int> data) {
    final incoming = utf8.decode(data);
    final buffer = (_receiveBuffers[socket] ?? '') + incoming;
    var remainder = buffer;

    while (remainder.contains('\n')) {
      final index = remainder.indexOf('\n');
      final rawMessage = remainder.substring(0, index).trim();
      remainder = remainder.substring(index + 1);
      if (rawMessage.isEmpty) {
        continue;
      }
      _handleIncomingMessage(rawMessage);
    }

    _receiveBuffers[socket] = remainder;
  }

  void _handleIncomingMessage(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is Map<String, dynamic>) {
        final payload = _extractPayload(decoded);
        final order = _orderFromPayload(payload);
        _receivedOrdersController.add(order);
      }
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  Map<String, dynamic> _extractPayload(Map<String, dynamic> decoded) {
    if (decoded['payload'] is Map) {
      return Map<String, dynamic>.from(decoded['payload'] as Map);
    }
    if (decoded['order'] is Map) {
      return Map<String, dynamic>.from(decoded['order'] as Map);
    }
    return decoded;
  }

  Order _orderFromPayload(Map<String, dynamic> payload) {
    if (payload.containsKey('orderNumber') && payload.containsKey('items')) {
      return Order.fromMap(payload);
    }

    final itemName = payload['item']?.toString() ?? 'Unknown Item';
    final qty = payload['qty'] is num
        ? (payload['qty'] as num).toInt()
        : int.tryParse(payload['qty']?.toString() ?? '') ?? 1;
    final price = payload['price'] is num
        ? (payload['price'] as num).toDouble()
        : 0.0;
    final items = [
      OrderItem(
        menuItemId: payload['id']?.toString() ?? '',
        name: itemName,
        price: price,
        icon: payload['icon']?.toString() ?? '☕',
        qty: qty,        sugarLevel: payload['sugarLevel']?.toString() ?? 'Regular sugar',      )
    ];

    final tableValue = payload['table']?.toString() ?? 'Unknown';
    final orderNumber = payload['orderNumber'] is num
        ? (payload['orderNumber'] as num).toInt()
        : int.tryParse(payload['orderNumber']?.toString() ?? '') ??
            DateTime.now().millisecondsSinceEpoch.remainder(1000000);
    final total = items.fold<double>(0, (sum, item) => sum + item.subtotal);

    return Order(
      id: payload['id']?.toString() ?? '',
      orderNumber: orderNumber,
      customerName: 'Table $tableValue',
      cashierName: payload['cashierName']?.toString() ?? 'Host',
      items: items,
      subtotal: total,
      discount: 0,
      discountLabel: '',
      vat: 0,
      total: total,
      tendered: total,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime.now(),
      status: _parseOrderStatus(payload['status']),
    );
  }

  OrderStatus _parseOrderStatus(dynamic rawValue) {
    if (rawValue is num) {
      final value = rawValue.toInt();
      if (value >= 0 && value < OrderStatus.values.length) {
        return OrderStatus.values[value];
      }
    }

    final value = rawValue?.toString().toLowerCase() ?? '';
    if (value.contains('void')) {
      return OrderStatus.voided;
    }
    if (value.contains('hold')) {
      return OrderStatus.held;
    }
    if (value.contains('pending')) {
      return OrderStatus.paid;
    }
    return OrderStatus.paid;
  }

  void _removeClient(Socket socket) {
    _connectedClients.remove(socket);
    _receiveBuffers.remove(socket);
    try {
      socket.destroy();
    } catch (_) {}
    _updatePeers();
    if (_connectedClients.isEmpty && _serverSocket != null) {
      _setStatus('listening');
    }
  }

  void _scheduleReconnectIfNeeded() {
    if (!_autoReconnect || _disposed) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (!_autoReconnect || _disposed) {
        return;
      }
      connectToHost(_host, port: _port);
    });
  }

  Future<String> _fetchLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 &&
              !address.isLoopback) {
            final raw = address.address;
            if (raw.startsWith('10.') ||
                raw.startsWith('192.168.') ||
                raw.startsWith('172.')) {
              return raw;
            }
          }
        }
      }
    } catch (_) {
      // ignore
    }
    return '0.0.0.0';
  }

  void _setStatus(String status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void _updatePeers() {
    final peers = <String>[];
    if (isServerMode) {
      peers.addAll(_connectedClients
          .map((socket) => '${socket.remoteAddress.address}:${socket.remotePort}'));
    } else if (_clientSocket != null) {
      peers.add('${_clientSocket!.remoteAddress.address}:${_clientSocket!.remotePort}');
    }
    if (!_peersController.isClosed) {
      _peersController.add(peers);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await stopServer();
    await disconnect();
    await _receivedOrdersController.close();
    await _statusController.close();
    await _peersController.close();
  }
}
