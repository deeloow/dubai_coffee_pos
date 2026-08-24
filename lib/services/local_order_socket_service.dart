import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'inventory_service.dart';
import 'menu_service.dart';
import 'order_service.dart';
import 'recipe_service.dart';
import 'report_service.dart';
import 'settings_service.dart';

class LocalOrderSocketService {
  static LocalOrderSocketService? _instance;
  final int defaultPort;

  factory LocalOrderSocketService({int defaultPort = 4567}) {
    _instance ??= LocalOrderSocketService._internal(defaultPort);
    return _instance!;
  }

  LocalOrderSocketService._internal(this.defaultPort) {
    _port = defaultPort;
  }
  ServerSocket? _serverSocket;
  Socket? _clientSocket;
  final List<Socket> _connectedClients = [];
  final Map<Socket, String> _receiveBuffers = {};
  final Map<Socket, bool> _clientHandshakeCompleted = {};
  final StreamController<Order> _receivedOrdersController =
      StreamController.broadcast();
  final StreamController<DateTime> _receivedReportResetController =
      StreamController.broadcast();
  final StreamController<String> _statusController =
      StreamController.broadcast();
  final StreamController<List<String>> _peersController =
      StreamController.broadcast();
  final StreamController<String> _errorController =
      StreamController.broadcast();
  final Duration _heartbeatInterval = const Duration(seconds: 12);

  bool _autoReconnect = false;
  bool _disposed = false;
  bool _handshakeComplete = false;
  Completer<void>? _handshakeCompleter;
  String _host = '0.0.0.0';
  int _port = 4567;
  Timer? _heartbeatTimer;
  Timer? _handshakeTimer;
  Timer? _reconnectTimer;
  final Map<Socket, Timer> _serverHandshakeTimers = {};

  // The shared singleton keeps the socket service state consistent across the
  // provider and inventory broadcast paths.

  Stream<Order> get receivedOrders => _receivedOrdersController.stream;
  Stream<DateTime> get receivedReportResets =>
      _receivedReportResetController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<List<String>> get connectedPeers => _peersController.stream;
  String get localAddress => _host;
  int get port => _port;
  bool get autoReconnect => _autoReconnect;
  bool get isServerMode => _serverSocket != null;

  void setAutoReconnect(bool enabled) {
    _autoReconnect = enabled;
    if (!enabled) {
      _cancelReconnectTimer();
    }
  }
  bool get isClientMode => _clientSocket != null;
  bool get isConnected =>
      isServerMode ? _connectedClients.isNotEmpty : _clientSocket != null;

  Future<void> startServer({int port = 4567}) async {
    if (_serverSocket != null) {
      if (port == 0 || _serverSocket!.port == port) {
        _port = _serverSocket!.port;
        _autoReconnect = false;
        _host = await _fetchLocalIpAddress();
        _setStatus('listening');
        _updatePeers();
        _startHeartbeat();
        return;
      }
      await stopServer();
    }

    await disconnect(preserveAutoReconnect: false);
    _port = port;
    _autoReconnect = false;
    _host = await _fetchLocalIpAddress();
    if (kDebugMode) {
      debugPrint('LocalOrderSocketService: starting server on $_host:$_port');
      debugPrint('LocalOrderSocketService: available local addresses:');
      _listLocalAddresses();
    }
    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      _port = _serverSocket!.port;
    } catch (error) {
      final message = _formatServerBindError(error);
      _reportError(message);
      _setStatus('error');
      rethrow;
    }
    final boundAddress = _serverSocket!.address.address;
    if (kDebugMode) {
      debugPrint('LocalOrderSocketService: server bound to $boundAddress:$_port');
    }
    _setStatus('listening');
    _updatePeers();
    _serverSocket!.listen(
      _handleNewClient,
      onError: (error) {
        final message = 'Server socket error: $error';
        _reportError(message);
        _setStatus('error');
      },
    );
    if (kDebugMode) {
      debugPrint('LocalOrderSocketService: server started and listening for clients on $_host:$_port');
    }
    _startHeartbeat();
  }

  Future<void> stopServer() async {
    _stopHeartbeat();
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
    if (kDebugMode) {
      debugPrint('LocalOrderSocketService: attempting connection to $host:$port');
    }
    if (!_validateHost(host)) {
      final message = 'Invalid Host IP: $host';
      _reportError(message);
      _setStatus('error');
      throw Exception(message);
    }
    if (!_validatePort(port)) {
      final message = 'Invalid port number: $port';
      _reportError(message);
      _setStatus('error');
      throw Exception(message);
    }
    await disconnect(preserveAutoReconnect: true);
    _host = host;
    _port = port;
    _autoReconnect = true;
    _handshakeComplete = false;
    _setStatus('connecting');

    try {
      final socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      _clientSocket = socket;
      _handshakeComplete = false;
      if (kDebugMode) {
        debugPrint('LocalOrderSocketService: TCP connection established to $host:$port, remote ${socket.remoteAddress.address}:${socket.remotePort}. Attaching listener and awaiting handshake');
      }
      _updatePeers();
      _receiveBuffers[socket] = '';
      _startHeartbeat();
      socket.listen(
        (data) => _handleSocketData(socket, data),
        onDone: () {
          final remote = '${socket.remoteAddress.address}:${socket.remotePort}';
          final message = _handshakeComplete
              ? 'Connection closed by server after handshake at $remote.'
              : 'Connection closed before handshake completed by remote $remote.';
          if (kDebugMode) {
            debugPrint('LocalOrderSocketService: client socket done (remote: $remote) on $_host:$_port');
            debugPrint('LocalOrderSocketService: client disconnect reason: $message');
          }
          if (!_handshakeComplete) {
            _completeHandshakeFailure(message);
          }
          _clientSocket = null;
          _reportError(message);
          _setStatus('disconnected');
          _updatePeers();
          if (_autoReconnect && !_disposed) {
            _scheduleReconnect();
          }
        },
        onError: (error) {
          final message = _formatConnectionError(error);
          final reason = _handshakeComplete
              ? 'Connection lost after handshake: $message'
              : 'Connection failed before handshake completed: $message';
          if (kDebugMode) {
            debugPrint('LocalOrderSocketService: client socket error: $error');
            try {
              debugPrint(error is Error ? error.stackTrace?.toString() ?? 'no stacktrace available' : 'no stacktrace available');
            } catch (_) {}
          }
          if (!_handshakeComplete) {
            _completeHandshakeFailure(reason);
          }
          _reportError(reason);
          _clientSocket = null;
          _cancelHandshakeTimeout();
          _setStatus('error');
          _updatePeers();
          if (_autoReconnect && !_disposed) {
            _scheduleReconnect();
          }
        },
        cancelOnError: true,
      );
      _handshakeCompleter = Completer<void>();
      _sendHello();
      _startHandshakeTimeout();
      await _handshakeCompleter!.future;
    } catch (error) {
      final message = error is SocketException
          ? _formatConnectionError(error)
          : error is Exception
              ? error.toString()
              : 'Connection failed: $error';
      _reportError(message);
      if (kDebugMode) {
        debugPrint('LocalOrderSocketService: connectToHost failed: $error');
      }
      _cancelHandshakeTimeout();
      _setStatus('error');
      _updatePeers();
      if (kDebugMode) {
        debugPrint('LocalOrderSocketService: connection failed; automatic reconnects remain enabled');
      }
      _scheduleReconnect();
      throw Exception(message);
    }
  }

  Future<void> disconnect({bool preserveAutoReconnect = false}) async {
    if (kDebugMode) {
      debugPrint('LocalOrderSocketService: disconnecting client socket');
    }
    _autoReconnect = preserveAutoReconnect;
    _handshakeComplete = false;
    _handshakeCompleter = null;
    _stopHeartbeat();
    try {
      await _clientSocket?.close();
    } catch (_) {}
    _clientSocket?.destroy();
    _clientSocket = null;
    _cancelHandshakeTimeout();
    _handshakeComplete = false;
    _setStatus('idle');
    _updatePeers();
  }

  void _sendHello() {
    if (_clientSocket == null) {
      return;
    }
    if (kDebugMode) {
      debugPrint('LocalOrderSocketService: sending hello to $_host:$_port');
    }
    try {
      _clientSocket!.write('${jsonEncode({'type': 'hello'})}\n');
      _clientSocket!.flush();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('LocalOrderSocketService: failed to send hello: $error');
      }
    }
  }

  Future<bool> sendOrder(Order order) async {
    final payload = {
      'type': 'order',
      'payload': order.toMap(),
    };
    return sendJson(payload);
  }

  Future<bool> sendOrderDelete(String orderId) async {
    final payload = {
      'type': 'order_delete',
      'payload': {'id': orderId},
    };
    return sendJson(payload);
  }

  Future<bool> sendJson(Map<String, dynamic> jsonMap, {Socket? target}) async {
    final message = '${jsonEncode(jsonMap)}\n';

    if (target != null) {
      try {
        if (kDebugMode) {
          try {
            debugPrint('LocalOrderSocketService: sending to ${target.remoteAddress.address}:${target.remotePort} -> $message');
          } catch (_) {
            debugPrint('LocalOrderSocketService: sending to target -> $message');
          }
        }
        target.write(message);
        await target.flush();
        return true;
      } catch (error) {
        final remote = '${target.remoteAddress.address}:${target.remotePort}';
        final reason = 'Send failed to $remote: $error. The connection will remain open.';
        _reportError(reason);
        if (kDebugMode) {
          debugPrint('LocalOrderSocketService: write error to $remote: $error');
        }
        return false;
      }
    }

    if (isServerMode && _connectedClients.isNotEmpty) {
      for (final socket in List<Socket>.from(_connectedClients)) {
        try {
          if (kDebugMode) {
            try {
              debugPrint('LocalOrderSocketService: broadcasting to ${socket.remoteAddress.address}:${socket.remotePort} -> $message');
            } catch (_) {
              debugPrint('LocalOrderSocketService: broadcasting to client -> $message');
            }
          }
          socket.write(message);
          await socket.flush();
        } catch (error) {
          final reason = 'Broadcast failed to ${socket.remoteAddress.address}:${socket.remotePort}: $error. The connection remains open.';
          _reportError(reason);
        }
      }
      return true;
    }

    if (isClientMode && _clientSocket != null) {
      try {
        if (kDebugMode) {
            try {
              debugPrint('LocalOrderSocketService: client sending -> $message');
            } catch (_) {}
          }
        _clientSocket!.write(message);
        await _clientSocket!.flush();
        return true;
      } catch (error) {
        final reason = 'Failed to send message to server: $error';
        _reportError(reason);
        if (kDebugMode) {
          debugPrint('LocalOrderSocketService: client write error: $error');
        }
        _setStatus('error');
        return false;
      }
    }

    return false;
  }

  Future<bool> sendReportReset(DateTime resetAt) async {
    return sendJson(
      {
        'type': 'report_reset',
        'payload': {'resetAt': resetAt.toIso8601String()},
      },
    );
  }

  Future<bool> sendMonthlyReportReset(DateTime resetAt) async {
    return sendJson(
      {
        'type': 'monthly_report_reset',
        'payload': {'resetAt': resetAt.toIso8601String()},
      },
    );
  }

  Future<bool> sendMenuSync(List<MenuItem> items) async {
    final categories = await MenuService().fetchCategoryEntries();
    return sendJson({
      'type': 'menu_sync',
      'payload': {
        'items': items.map((item) => item.toMap()..['id'] = item.id).toList(),
        'categories': categories,
      },
    });
  }

  Future<bool> sendQrSync(
      {String? path, String? base64, String? mimeType, String? gcashNumber}) async {
    return sendJson({
      'type': 'qr_sync',
      'payload': {
        'path': path,
        'base64': base64,
        'mimeType': mimeType,
        'gcashNumber': gcashNumber,
      },
    });
  }

  Future<bool> sendInventoryUpdate(InventoryItem item) async {
    return sendJson({
      'type': 'inventory_update',
      'payload': {
        'id': item.id,
        'quantity': item.quantity,
        'servedQuantity': item.servedQuantity,
      },
    });
  }

  Future<bool> sendInventorySync() async {
    final invService = InventoryService();
    final items = await invService.fetchAllInventory();
    return sendJson({
      'type': 'inventory_sync',
      'payload': {
        'items': items.map((item) => item.toMap()..['id'] = item.id).toList(),
      },
    });
  }

  Future<bool> sendReportState() async {
    final reportDate = await ReportService().currentReportDate();
    return sendJson(
      {
        'type': 'report_state',
        'payload': {'resetAt': reportDate.toIso8601String()},
      },
    );
  }

  Future<bool> sendMonthlyReportState() async {
    final monthDate = await ReportService().currentReportMonth();
    return sendJson(
      {
        'type': 'monthly_report_state',
        'payload': {'resetAt': monthDate.toIso8601String()},
      },
    );
  }

  Future<bool> _sendReportState(Socket socket) async {
    final reportDate = await ReportService().currentReportDate();
    return sendJson(
      {
        'type': 'report_state',
        'payload': {'resetAt': reportDate.toIso8601String()},
      },
      target: socket,
    );
  }

  Future<bool> _sendMonthlyReportState(Socket socket) async {
    final monthDate = await ReportService().currentReportMonth();
    return sendJson(
      {
        'type': 'monthly_report_state',
        'payload': {'resetAt': monthDate.toIso8601String()},
      },
      target: socket,
    );
  }

  Future<void> _sendAllOrders(Socket socket) async {
    final orders = await OrderService().fetchOrders(includeArchived: false);
    for (final order in orders) {
      await sendJson(
        {
          'type': 'order_sync',
          'payload': order.toMap(),
        },
        target: socket,
      );
    }
  }

  Future<void> _sendMenuState(Socket socket) async {
    final items = await MenuService().fetchMenuItems();
    final categories = await MenuService().fetchCategoryEntries();
    await sendJson(
      {
        'type': 'menu_sync',
        'payload': {
          'items': items.map((item) => item.toMap()..['id'] = item.id).toList(),
          'categories': categories,
        },
      },
      target: socket,
    );
  }

  Future<void> _sendInventoryState(Socket socket) async {
    final invService = InventoryService();
    final items = await invService.fetchAllInventory();
    await sendJson(
      {
        'type': 'inventory_sync',
        'payload': {
          'items': items.map((item) => item.toMap()..['id'] = item.id).toList(),
        },
      },
      target: socket,
    );
  }

  Future<void> _sendQrState(Socket socket) async {
    final settings = SettingsService();
    final path = settings.paymentQrCodePath;
    final base64 = settings.paymentQrCodeBase64;
    await sendJson(
      {
        'type': 'qr_sync',
        'payload': {
          'path': path,
          'base64': base64,
          'mimeType': settings.paymentQrCodeMimeType,
          'gcashNumber': settings.gcashNumber,
        },
      },
      target: socket,
    );
  }

  Future<void> _startInitialSyncForClient(Socket socket) async {
    if (kDebugMode) {
      debugPrint('LocalOrderSocketService: starting initial sync after handshake for ${socket.remoteAddress.address}:${socket.remotePort}');
    }

    try {
      await _sendReportState(socket);
    } catch (e, st) {
      _reportError('Error sending report state: $e');
      if (kDebugMode) {
        try {
          debugPrint(st.toString());
        } catch (_) {}
      }
    }

    try {
      await _sendMonthlyReportState(socket);
    } catch (e, st) {
      _reportError('Error sending monthly report state: $e');
      if (kDebugMode) {
        try {
          debugPrint(st.toString());
        } catch (_) {}
      }
    }

    try {
      await _sendInventoryState(socket);
    } catch (e, st) {
      _reportError('Error sending inventory state during initial sync: $e');
      if (kDebugMode) {
        try {
          debugPrint(st.toString());
        } catch (_) {}
      }
    }

    try {
      await _sendMenuState(socket);
    } catch (e, st) {
      _reportError('Error sending menu state during initial sync: $e');
      if (kDebugMode) {
        try {
          debugPrint(st.toString());
        } catch (_) {}
      }
    }

    try {
      await _sendAllOrders(socket);
    } catch (e, st) {
      _reportError('Error sending orders during initial sync: $e');
      if (kDebugMode) {
        try {
          debugPrint(st.toString());
        } catch (_) {}
      }
    }

    try {
      await _sendQrState(socket);
    } catch (e, st) {
      _reportError('Error sending QR state during initial sync: $e');
      if (kDebugMode) {
        try {
          debugPrint(st.toString());
        } catch (_) {}
      }
    }

    if (kDebugMode) {
      debugPrint('LocalOrderSocketService: completed initial sync for ${socket.remoteAddress.address}:${socket.remotePort}');
    }
  }

  Future<void> _handleNewClient(Socket socket) async {
    if (kDebugMode) {
      debugPrint('LocalOrderSocketService: accepted client connection from ${socket.remoteAddress.address}:${socket.remotePort}');
    }
    _connectedClients.add(socket);
    _receiveBuffers[socket] = '';
    _clientHandshakeCompleted[socket] = false;
    _setStatus('connected');
    _updatePeers();
    _startServerHandshakeTimeout(socket);

    if (kDebugMode) {
      debugPrint('LocalOrderSocketService: client connected ${socket.remoteAddress.address}:${socket.remotePort}');
      debugPrint('LocalOrderSocketService: waiting for handshake from ${socket.remoteAddress.address}:${socket.remotePort}');
    }

    socket.listen(
      (data) => _handleSocketData(socket, data),
      onDone: () {
        if (kDebugMode) {
          try {
            debugPrint('LocalOrderSocketService: client disconnected ${socket.remoteAddress.address}:${socket.remotePort}');
          } catch (_) {
            debugPrint('LocalOrderSocketService: client disconnected (remote address unavailable)');
          }
        }
        _removeClient(socket);
      },
      onError: (error) {
        final msg = _formatConnectionError(error);
        try {
          _reportError('Client socket error (${socket.remoteAddress.address}:${socket.remotePort}): $msg');
        } catch (_) {
          _reportError('Client socket error (remote address unavailable): $msg');
        }
        if (kDebugMode) {
          debugPrint('LocalOrderSocketService: client listen error: $error');
        }
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
      if (kDebugMode) {
        try {
          debugPrint('LocalOrderSocketService: raw message from ${socket.remoteAddress.address}:${socket.remotePort} -> $rawMessage');
        } catch (_) {
          debugPrint('LocalOrderSocketService: raw message from socket -> $rawMessage');
        }
      }
      _handleIncomingMessage(rawMessage, sourceSocket: socket);
    }

    _receiveBuffers[socket] = remainder;
  }

  Future<void> _handleIncomingMessage(String rawMessage,
      {Socket? sourceSocket}) async {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type']?.toString();
        final payload = _extractPayload(decoded);

        if (type == 'report_reset') {
          await _handleReportReset(payload);
          if (isServerMode && sourceSocket != null) {
            final latestResetAt = payload['resetAt']?.toString();
            final resetDate = latestResetAt != null
                ? DateTime.tryParse(latestResetAt)
                : null;
            if (resetDate != null) {
              final statePayload = {
                'type': 'report_state',
                'payload': {'resetAt': resetDate.toIso8601String()},
              };
              for (final client in List<Socket>.from(_connectedClients)) {
                await sendJson(statePayload, target: client);
              }
              await sendJson(statePayload, target: sourceSocket);
            }
          }
          return;
        }

        if (type == 'monthly_report_reset') {
          _handleMonthlyReportReset(payload);
          if (isServerMode && sourceSocket != null) {
            for (final client in List<Socket>.from(_connectedClients)) {
              if (client != sourceSocket) {
                sendJson(
                  {
                    'type': 'monthly_report_reset',
                    'payload': payload,
                  },
                  target: client,
                );
              }
            }
          }
          return;
        }

        if (type == 'report_state') {
          _handleReportState(payload);
          return;
        }

        if (type == 'monthly_report_state') {
          _handleMonthlyReportState(payload);
          return;
        }

        if (type == 'ping') {
          if (isServerMode && sourceSocket != null) {
            sendJson({'type': 'pong'}, target: sourceSocket);
          } else if (isClientMode) {
            sendJson({'type': 'pong'});
          }
          return;
        }

        if (type == 'pong') {
          _setStatus('connected');
          return;
        }

        if (type == 'hello') {
          if (isServerMode && sourceSocket != null) {
            if (kDebugMode) {
              debugPrint('LocalOrderSocketService: received handshake hello from ${sourceSocket.remoteAddress.address}:${sourceSocket.remotePort}');
            }
            _clientHandshakeCompleted[sourceSocket] = true;
            _cancelServerHandshakeTimeout(sourceSocket);
            if (kDebugMode) {
              debugPrint('LocalOrderSocketService: sending welcome to ${sourceSocket.remoteAddress.address}:${sourceSocket.remotePort}');
            }
            sendJson({'type': 'welcome'}, target: sourceSocket);
            if (kDebugMode) {
              debugPrint('LocalOrderSocketService: handshake completed for ${sourceSocket.remoteAddress.address}:${sourceSocket.remotePort}');
            }
            unawaited(_startInitialSyncForClient(sourceSocket));
          }
          return;
        }

        if (type == 'welcome') {
          if (isClientMode) {
            _handshakeComplete = true;
            _cancelHandshakeTimeout();
            _autoReconnect = false;
            if (kDebugMode) {
              debugPrint('LocalOrderSocketService: handshake welcome received from server');
            }
            _setStatus('connected');
            _updatePeers();
            _completeHandshakeSuccess();
          }
          return;
        }

        if (type == 'order' || type == 'order_sync') {
          final order = _orderFromPayload(payload);
          _receivedOrdersController.add(order);

          if (isServerMode && sourceSocket != null && type == 'order') {
            // Admin broadcasts completed orders to ALL other connected devices (not just baristas)
            // This ensures Kitchen queue stays in sync when ANY device marks order Done
            for (final client in List<Socket>.from(_connectedClients)) {
              if (client != sourceSocket) {
                sendJson(
                  {
                    'type': 'order',
                    'payload': order.toMap(),
                  },
                  target: client,
                );
              }
            }

            if (order.status == OrderStatus.completed) {
              // Ensure all devices receive the latest report state from Admin after a barista completes an order.
              await sendReportState();
              await sendMonthlyReportState();
            }
          }
          return;
        }

        if (type == 'order_delete') {
          final orderId = payload['id']?.toString();
          if (orderId != null && orderId.isNotEmpty) {
            await OrderService().deleteOrder(orderId);
          }

          if (isServerMode && sourceSocket != null) {
            for (final client in List<Socket>.from(_connectedClients)) {
              if (client != sourceSocket) {
                sendJson(
                  {
                    'type': 'order_delete',
                    'payload': {'id': orderId},
                  },
                  target: client,
                );
              }
            }
          }
          return;
        }

        if (type == 'menu_sync') {
          final categoriesPayload = payload['categories'];
          if (categoriesPayload is List) {
            final categories = categoriesPayload.whereType<Map>().map((entry) {
              return Map<String, dynamic>.from(entry);
            }).toList();
            await MenuService().replaceCategoriesWithEntries(categories);
          }

          final itemsPayload = payload['items'];
          if (itemsPayload is List) {
            final items = itemsPayload.whereType<Map>().map((item) {
              final map = Map<String, dynamic>.from(item);
              return MenuItem.fromMap(map, id: map['id']?.toString());
            }).toList();
            await MenuService().replaceMenuWithItems(items);
            
            // Create recipes for all menu items
            final recipeService = RecipeService();
            for (final item in items) {
              await recipeService.createRecipeForMenuItem(item);
            }
            if (kDebugMode) {
              debugPrint('LocalOrderSocketService: created recipes for ${items.length} synced menu items');
            }
          }

          if (isServerMode && sourceSocket != null) {
            for (final client in List<Socket>.from(_connectedClients)) {
              if (client != sourceSocket) {
                sendJson(
                  {
                    'type': 'menu_sync',
                    'payload': payload,
                  },
                  target: client,
                );
              }
            }
          }
          return;
        }

        if (type == 'qr_sync') {
          await SettingsService().applyRemoteQrState(
            path: payload['path']?.toString(),
            base64: payload['base64']?.toString(),
            mimeType: payload['mimeType']?.toString(),
            gcashNumber: payload['gcashNumber']?.toString(),
          );

          if (isServerMode && sourceSocket != null) {
            for (final client in List<Socket>.from(_connectedClients)) {
              if (client != sourceSocket) {
                sendJson(
                  {
                    'type': 'qr_sync',
                    'payload': payload,
                  },
                  target: client,
                );
              }
            }
          }
          return;
        }

        if (type == 'inventory_update') {
          await _handleInventoryUpdate(payload);
          if (isServerMode && sourceSocket != null) {
            for (final client in List<Socket>.from(_connectedClients)) {
              if (client != sourceSocket) {
                sendJson(
                  {
                    'type': 'inventory_update',
                    'payload': payload,
                  },
                  target: client,
                );
              }
            }
          }
          return;
        }

        if (type == 'inventory_sync') {
          await _handleInventorySyncMessage(payload);
          return;
        }

        if (!isClientMode && sourceSocket != null && _clientHandshakeCompleted[sourceSocket] != true) {
          final reason = 'Handshake message expected first. Received "$type" before handshake completed.';
          _reportError(reason);
          if (kDebugMode) {
            debugPrint('LocalOrderSocketService: protocol error from ${sourceSocket.remoteAddress.address}:${sourceSocket.remotePort}: $reason');
          }
          sendJson(
            {
              'type': 'error',
              'payload': {'message': reason},
            },
            target: sourceSocket,
          );
        }
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('LocalOrderSocketService: failed to parse incoming message: $error');
        try {
          debugPrint(stackTrace.toString());
        } catch (_) {}
      }
      _reportError('Malformed payload received: $error');
    }
  }

  Future<void> _handleReportReset(Map<String, dynamic> payload) async {
    final rawResetAt = payload['resetAt']?.toString();
    final resetAt = rawResetAt != null ? DateTime.tryParse(rawResetAt) : null;
    if (resetAt == null) {
      return;
    }

    await ReportService().applyRemoteReset(resetAt);
    if (!_receivedReportResetController.isClosed) {
      _receivedReportResetController.add(resetAt);
    }
    debugPrint('Received daily report reset event for $resetAt');
  }

  void _handleMonthlyReportReset(Map<String, dynamic> payload) {
    final rawResetAt = payload['resetAt']?.toString();
    final resetAt = rawResetAt != null ? DateTime.tryParse(rawResetAt) : null;
    if (resetAt == null) {
      return;
    }

    ReportService().applyRemoteMonthlyReset(resetAt);
    debugPrint('Received monthly report reset event for $resetAt');
  }

  void _handleReportState(Map<String, dynamic> payload) {
    final rawResetAt = payload['resetAt']?.toString();
    final resetAt = rawResetAt != null ? DateTime.tryParse(rawResetAt) : null;
    if (resetAt == null) {
      return;
    }

    ReportService().applyRemoteDailyState(resetAt);
    debugPrint('Received daily report state sync for $resetAt');
  }

  void _handleMonthlyReportState(Map<String, dynamic> payload) {
    final rawResetAt = payload['resetAt']?.toString();
    final resetAt = rawResetAt != null ? DateTime.tryParse(rawResetAt) : null;
    if (resetAt == null) {
      return;
    }

    ReportService().applyRemoteMonthlyState(resetAt);
    debugPrint('Received monthly report state sync for $resetAt');
  }

  Future<void> _handleInventoryUpdate(Map<String, dynamic> payload) async {
    final id = payload['id']?.toString();
    final quantity = payload['quantity'] is num
        ? (payload['quantity'] as num).toDouble()
        : double.tryParse(payload['quantity']?.toString() ?? '') ?? 0.0;
    final servedQuantity = payload['servedQuantity'] is num
        ? (payload['servedQuantity'] as num).toDouble()
        : double.tryParse(payload['servedQuantity']?.toString() ?? '') ?? 0.0;

    if (id == null || id.isEmpty) {
      return;
    }

    final invService = InventoryService();
    final inventory = await invService.fetchInventoryItem(id);
    if (inventory != null) {
      final updated = inventory.copyWith(
        quantity: quantity,
        servedQuantity: servedQuantity,
      );
      await invService.updateItem(updated);
      debugPrint('Received inventory update for ${inventory.name}: $quantity ${inventory.unit}');
    }
  }

  Future<void> _handleInventorySyncMessage(Map<String, dynamic> payload) async {
    final itemsPayload = payload['items'];
    if (itemsPayload is List) {
      final invService = InventoryService();
      final items = itemsPayload.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        return InventoryItem.fromMap(map, id: map['id']?.toString());
      }).toList();

      // Replace inventory completely (clear all existing and rebuild from admin's state)
      // This prevents duplicate 12oz/16oz cups on barista devices
      if (!isServerMode) {
        // Only do full replacement on barista (client) side
        await invService.clearAndReplaceWithItems(items);
      } else {
        // On admin (server) side, update existing items
        for (final item in items) {
          await invService.updateItem(item);
        }
      }
      debugPrint('Received full inventory sync with ${items.length} items');
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
    final price =
        payload['price'] is num ? (payload['price'] as num).toDouble() : 0.0;
    final items = [
      OrderItem(
        menuItemId: payload['id']?.toString() ?? '',
        name: itemName,
        price: price,
        icon: payload['icon']?.toString() ?? '☕',
        qty: qty,
        sugarLevel: payload['sugarLevel']?.toString() ?? 'Regular sugar',
        cupSize: payload['cupSize']?.toString() ?? '12oz',
      )
    ];

    final tableValue = payload['table']?.toString() ?? 'Unknown';
    final orderNumber = payload['orderNumber'] is num
        ? (payload['orderNumber'] as num).toInt()
        : int.tryParse(payload['orderNumber']?.toString() ?? '') ??
            DateTime.now().millisecondsSinceEpoch.remainder(1000000);
    final total = items.fold<double>(0, (sum, item) => sum + item.subtotal);

    DateTime createdAtValue;
    final createdAtRaw = payload['createdAt'];
    if (createdAtRaw is DateTime) {
      createdAtValue = createdAtRaw;
    } else if (createdAtRaw is String) {
      createdAtValue = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      createdAtValue = DateTime.now();
    }

    return Order(
      id: payload['id']?.toString() ?? '',
      orderNumber: orderNumber,
      customerName: 'Table $tableValue',
      cashierName: payload['cashierName']?.toString() ?? 'Host',
      items: items,
      subtotal: total,
      discount: 0,
      discountLabel: '',
      total: total,
      tendered: total,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: createdAtValue,
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
    if (value.contains('checked')) {
      return OrderStatus.checked;
    }
    if (value.contains('ready')) {
      return OrderStatus.ready;
    }
    if (value.contains('complete')) {
      return OrderStatus.completed;
    }
    if (value.contains('paid') || value.contains('pending')) {
      return OrderStatus.paid;
    }
    return OrderStatus.paid;
  }

  void _removeClient(Socket socket) {
    _connectedClients.remove(socket);
    _receiveBuffers.remove(socket);
    _clientHandshakeCompleted.remove(socket);
    _cancelServerHandshakeTimeout(socket);
    try {
      socket.destroy();
    } catch (_) {}
    _updatePeers();
    if (_connectedClients.isEmpty && _serverSocket != null) {
      _setStatus('listening');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    if (_disposed) {
      return;
    }

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_disposed) {
        _stopHeartbeat();
        return;
      }

      if (isClientMode && _clientSocket != null) {
        if (kDebugMode) {
            debugPrint('LocalOrderSocketService: sending ping to server');
          }
        sendJson({'type': 'ping'});
      } else if (isServerMode && _connectedClients.isNotEmpty) {
        for (final client in List<Socket>.from(_connectedClients)) {
          if (kDebugMode) {
            debugPrint('LocalOrderSocketService: sending ping to client ${client.remoteAddress.address}:${client.remotePort}');
          }
          sendJson({'type': 'ping'}, target: client);
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _startHandshakeTimeout() {
    _handshakeTimer?.cancel();
    _handshakeTimer = Timer(const Duration(seconds: 4), () {
      if (!_handshakeComplete && _clientSocket != null) {
        const message = 'Handshake failed: did not receive welcome from server.';
        _reportError(message);
        if (kDebugMode) {
          final remote = '${_clientSocket!.remoteAddress.address}:${_clientSocket!.remotePort}';
          debugPrint('LocalOrderSocketService: handshake timed out for $_host:$_port (remote: $remote)');
        }
        // Complete the handshake as a failure so any awaiting flows know why it failed.
        _completeHandshakeFailure(message);
        // Close the socket gracefully rather than abruptly destroying it so logs and
        // any pending writes can be flushed and clearer reasons can be surfaced.
        try {
          _clientSocket?.close();
        } catch (_) {}
        try {
          _clientSocket?.destroy();
        } catch (_) {}
        _clientSocket = null;
        _setStatus('error');
        _updatePeers();
        _handshakeTimer = null;
      }
    });
  }

  void _cancelHandshakeTimeout() {
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _scheduleReconnect() {
    if (_disposed || !_autoReconnect || _clientSocket != null || _serverSocket != null) {
      return;
    }
    if (_reconnectTimer != null) {
      return;
    }
    _setStatus('reconnecting');
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      _reconnectTimer = null;
      unawaited(_attemptReconnect());
    });
  }

  Future<void> _attemptReconnect() async {
    if (_disposed || !_autoReconnect) {
      return;
    }
    if (_clientSocket != null || _serverSocket != null) {
      return;
    }
    if (_host.isEmpty || _port <= 0) {
      return;
    }
    try {
      await connectToHost(_host, port: _port);
    } catch (error) {
      _reportError('Automatic reconnect failed: $error');
      if (_autoReconnect && !_disposed) {
        _scheduleReconnect();
      }
    }
  }

  void _completeHandshakeSuccess() {
    _autoReconnect = true;
    if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
      _handshakeCompleter!.complete();
    }
    _handshakeCompleter = null;
  }

  void _completeHandshakeFailure(String message) {
    if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
      _handshakeCompleter!.completeError(Exception(message));
    }
    _handshakeCompleter = null;
  }

  Future<String> _fetchLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final candidates = <MapEntry<NetworkInterface, InternetAddress>>[];
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
            candidates.add(MapEntry(interface, address));
          }
        }
      }

      if (candidates.isEmpty) {
        final loopbackInterfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: true,
        );
        for (final interface in loopbackInterfaces) {
          for (final address in interface.addresses) {
            if (address.type == InternetAddressType.IPv4) {
              candidates.add(MapEntry(interface, address));
            }
          }
        }
      }

      if (candidates.isEmpty) {
        return '127.0.0.1';
      }

      candidates.sort((a, b) {
        final rankA = _rankAddress(a.key.name, a.value.address);
        final rankB = _rankAddress(b.key.name, b.value.address);
        return rankA.compareTo(rankB);
      });

      return candidates.first.value.address;
    } catch (_) {
      // ignore
    }
    return '127.0.0.1';
  }

  int _rankAddress(String interfaceName, String address) {
    var score = 1000;
    final name = interfaceName.toLowerCase();
    if (name.contains('wlan') ||
        name.contains('wifi') ||
        name.contains('wi-fi') ||
        name.contains('ap') ||
        name.contains('softap') ||
        name.contains('rndis') ||
        name.contains('en')) {
      score -= 200;
    }
    if (address.startsWith('192.168.')) {
      score -= 150;
    } else if (address.startsWith('10.')) {
      score -= 100;
    } else if (address.startsWith('172.')) {
      score -= 50;
    }
    if (name.contains('rmnet') ||
        name.contains('wwan') ||
        name.contains('cell')) {
      score += 250;
    }
    return score;
  }

  void _setStatus(String status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void _startServerHandshakeTimeout(Socket socket) {
    _cancelServerHandshakeTimeout(socket);
    _serverHandshakeTimers[socket] = Timer(const Duration(seconds: 10), () {
      if (_clientHandshakeCompleted[socket] != true) {
        final reason = 'Handshake timeout: no hello received from ${socket.remoteAddress.address}:${socket.remotePort}';
        _reportError(reason);
        if (kDebugMode) {
          debugPrint('LocalOrderSocketService: $reason');
        }
        try {
          sendJson(
            {
              'type': 'error',
              'payload': {'message': reason},
            },
            target: socket,
          );
        } catch (_) {}
        try {
          socket.destroy();
        } catch (_) {}
        _removeClient(socket);
      }
    });
  }

  void _cancelServerHandshakeTimeout(Socket socket) {
    _serverHandshakeTimers[socket]?.cancel();
    _serverHandshakeTimers.remove(socket);
  }

  void _listLocalAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) {
            if (kDebugMode) {
              debugPrint('LocalOrderSocketService: local interface ${interface.name} address ${address.address}');
            }
          }
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('LocalOrderSocketService: failed to list local addresses: $error');
      }
    }
  }

  void _updatePeers() {
    final peers = <String>[];
    if (isServerMode) {
      peers.addAll(_connectedClients.map(
          (socket) => '${socket.remoteAddress.address}:${socket.remotePort}'));
    } else if (_clientSocket != null) {
      peers.add(
          '${_clientSocket!.remoteAddress.address}:${_clientSocket!.remotePort}');
    }
    if (!_peersController.isClosed) {
      _peersController.add(peers);
    }
  }

  void _reportError(String message) {
    if (kDebugMode) {
      debugPrint('LocalOrderSocketService: ERROR: $message');
    }
    if (!_errorController.isClosed) {
      _errorController.add(message);
    }
  }

  String _formatConnectionError(Object error) {
    if (error is SocketException) {
      final message = error.message.toLowerCase();
      if (message.contains('timed out')) {
        return 'Connection timed out while reaching the Admin device.';
      }
      if (message.contains('connection refused')) {
        return 'Connection refused by the Admin server.';
      }
      if (message.contains('network is unreachable')) {
        return 'Unable to reach the Admin device: network unavailable.';
      }
      if (message.contains('connection reset by peer') ||
          message.contains('broken pipe')) {
        return 'The server closed the connection unexpectedly.';
      }
      if (message.contains('host is down')) {
        return 'The Admin device is offline or unreachable.';
      }
      if (message.contains('lookup')) {
        return 'Invalid Host IP or name: $error';
      }
      return 'Connection failed: ${error.message}';
    }
    return 'Connection failed: $error';
  }

  String _formatServerBindError(Object error) {
    if (error is SocketException) {
      final message = error.message.toLowerCase();
      if (message.contains('address already in use')) {
        return 'Port $_port is already in use. Please choose a different port.';
      }
      return 'Unable to start server: ${error.message}';
    }
    return 'Unable to start server: $error';
  }

  bool _validateHost(String host) {
    if (host.isEmpty) {
      return false;
    }
    final address = InternetAddress.tryParse(host);
    return address != null && address.type == InternetAddressType.IPv4;
  }

  bool _validatePort(int port) {
    return port > 0 && port <= 65535;
  }

  Future<void> dispose() async {
    _disposed = true;
    _autoReconnect = false;
    _cancelReconnectTimer();
    await stopServer();
    await disconnect();
    await _receivedOrdersController.close();
    await _receivedReportResetController.close();
    await _statusController.close();
    await _peersController.close();
    await _errorController.close();
  }
}
