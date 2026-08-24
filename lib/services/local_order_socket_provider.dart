import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'local_order_socket_service.dart';
import 'order_service.dart';

// Recent hosts feature removed per request: host history and HostEntry were deleted.

class LocalOrderSocketProvider extends ChangeNotifier {
  // Recent hosts feature removed: no persistent recent host storage.

  final LocalOrderSocketService _socketService;

  LocalOrderSocketProvider({LocalOrderSocketService? socketService})
      : _socketService = socketService ?? LocalOrderSocketService();
  final Uuid _uuid = const Uuid();
  // Removed unused settings box reference to clean analyzer warnings.

  bool _initialized = false;
  bool _isServer = false;
  bool _userRequestedDisconnect = false;
  String _status = 'idle';
  String? _error;
  String _host = '';
  int _port = 4567;
  String _localAddress = '';
  final List<String> _connectedPeers = [];
  final List<Order> _receivedOrders = [];
  Order? _lastReceivedOrder;

  StreamSubscription<Order>? _receivedSubscription;
  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<List<String>>? _peersSubscription;
  StreamSubscription<DateTime>? _reportResetSubscription;
  DateTime? _pendingReportResetAt;

  bool get isServer => _isServer;
  bool get isConnected => _connectedPeers.isNotEmpty;
  String get status => _status;
  String get connectionState {
    switch (_status) {
      case 'connecting':
        return 'Connecting';
      case 'connected':
        return 'Connected';
      case 'reconnecting':
        return 'Reconnecting';
      case 'listening':
        return 'Listening';
      case 'idle':
        return 'Disconnected';
      case 'error':
        return 'Connection error';
      case 'received':
        return 'Connected';
      case 'syncing':
        return 'Syncing';
      default:
        return _status;
    }
  }

  String? get error => _error;
  String get host => _host;
  int get port => _port;

  // Auto-reconnect is now driven by the socket service so reconnects can happen
  // automatically after app lifecycle interruptions.
  bool get shouldAutoReconnect => _socketService.autoReconnect;
  String get localAddress => _localAddress;
  List<String> get connectedPeers => List.unmodifiable(_connectedPeers);
  List<Order> get receivedOrders => List.unmodifiable(_receivedOrders);
  Order? get lastReceivedOrder => _lastReceivedOrder;
  DateTime? get pendingReportResetAt => _pendingReportResetAt;
  bool get hasPendingReportReset => _pendingReportResetAt != null;

  void acknowledgeReportReset() {
    if (_pendingReportResetAt != null) {
      _pendingReportResetAt = null;
      notifyListeners();
    }
  }

  void init() {
    if (_initialized) return;
    _initialized = true;
    _receivedSubscription = _socketService.receivedOrders.listen(
      (order) async {
        _lastReceivedOrder = order;
        _receivedOrders.removeWhere((existing) => existing.id == order.id);
        _receivedOrders.insert(0, order);
        _status = 'received';
        _error = null;
        notifyListeners();
        await _saveReceivedOrder(
          order,
          deductInventory: _isServer &&
              (order.status == OrderStatus.paid || order.status == OrderStatus.completed),
        );
      },
      onError: (error) {
        _error = error.toString();
        _status = 'error';
        notifyListeners();
      },
    );

    _statusSubscription = _socketService.statusStream.listen(
      (status) {
        _status = status;
        if (status == 'connecting' || status == 'connected' || status == 'listening') {
          _error = null;
        }
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _status = 'error';
        notifyListeners();
      },
    );

    _errorSubscription = _socketService.errorStream.listen(
      (errorMessage) {
        _error = errorMessage;
        _status = 'error';
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _status = 'error';
        notifyListeners();
      },
    );

    _peersSubscription = _socketService.connectedPeers.listen(
      (peers) {
        _connectedPeers
          ..clear()
          ..addAll(peers);
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _status = 'error';
        notifyListeners();
      },
    );

    _reportResetSubscription = _socketService.receivedReportResets.listen(
      (resetAt) {
        _pendingReportResetAt = resetAt;
        _status = 'report_reset_received';
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _status = 'error';
        notifyListeners();
      },
    );
  }

  Future<bool> startServer({int port = 4567}) async {
    _userRequestedDisconnect = false;
    try {
      _status = 'starting';
      _error = null;
      notifyListeners();
      _socketService.setAutoReconnect(false);
      await _socketService.startServer(port: port);
      _isServer = true;
      _localAddress = _socketService.localAddress;
      _port = _socketService.port;
      _host = _localAddress;
      _status = 'listening';
      notifyListeners();
      return true;
    } catch (error) {
      _error = error.toString();
      _status = 'error';
      _isServer = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> connect(String host, {int port = 4567}) async {
    _userRequestedDisconnect = false;
    try {
      _isServer = false;
      _status = 'connecting';
      _error = null;
      _host = host;
      _socketService.setAutoReconnect(true);
      _port = port;
      notifyListeners();
      await _socketService.connectToHost(host, port: port);
      _status = 'connecting';
      _error = null;
      // Recent hosts persistence removed. Connection uses only the provided host.
      notifyListeners();
      return true;
    } catch (error) {
      _error = error.toString();
      _status = 'error';
      notifyListeners();
      return false;
    }
  }

  Future<void> removeRecentHost(String host, int port) async {
    // Recent hosts management removed. This method retained as a no-op to avoid
    // breaking references from UI; callers should be removed from UI as well.
    // If caller remains, simply notify listeners to keep behavior stable.
    notifyListeners();
  }

  Future<void> resumeConnection() async {
    if (!_initialized) {
      init();
    }

    if (_userRequestedDisconnect) {
      return;
    }

    if (_isServer) {
      if (_socketService.isServerMode || _socketService.isConnected) {
        return;
      }
      if (_port > 0) {
        _status = 'reconnecting';
        _error = null;
        notifyListeners();
        try {
          await startServer(port: _port);
        } catch (_) {
          // status and error are already handled by startServer.
        }
      }
      return;
    }

    if (_host.isEmpty || _port <= 0) {
      return;
    }

    if (_socketService.isConnected || _socketService.isClientMode) {
      return;
    }

    _socketService.setAutoReconnect(true);
    _status = 'reconnecting';
    _error = null;
    notifyListeners();
    try {
      await _socketService.connectToHost(_host, port: _port);
    } catch (_) {
      // leave status/error updates to the socket service stream listeners.
    }
  }

  Future<bool> sendOrder(Order order) async {
    if (!_socketService.isConnected) {
      _error = 'No active connection';
      _status = 'offline';
      notifyListeners();
      return false;
    }

    try {
      _status = 'syncing';
      _error = null;
      notifyListeners();
      final ok = await _socketService.sendOrder(order);
      _status = ok ? 'connected' : 'error';
      if (!ok) {
        _error = 'Failed to send order';
      }
      notifyListeners();
      return ok;
    } catch (error) {
      _error = error.toString();
      _status = 'error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendOrderDelete(String orderId) async {
    if (!_socketService.isConnected) {
      _error = 'No active connection';
      _status = 'offline';
      notifyListeners();
      return false;
    }

    try {
      _status = 'syncing';
      _error = null;
      notifyListeners();
      final ok = await _socketService.sendOrderDelete(orderId);
      _status = ok ? 'connected' : 'error';
      if (!ok) {
        _error = 'Failed to send order delete';
      }
      notifyListeners();
      return ok;
    } catch (error) {
      _error = error.toString();
      _status = 'error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendReportState() async {
    if (!_socketService.isConnected) {
      _error = 'No active connection';
      _status = 'offline';
      notifyListeners();
      return false;
    }

    try {
      _status = 'syncing';
      _error = null;
      notifyListeners();
      final ok = await _socketService.sendReportState();
      _status = ok ? 'connected' : 'error';
      if (!ok) {
        _error = 'Failed to send report state';
      }
      notifyListeners();
      return ok;
    } catch (error) {
      _error = error.toString();
      _status = 'error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendMonthlyReportState() async {
    if (!_socketService.isConnected) {
      _error = 'No active connection';
      _status = 'offline';
      notifyListeners();
      return false;
    }

    try {
      _status = 'syncing';
      _error = null;
      notifyListeners();
      final ok = await _socketService.sendMonthlyReportState();
      _status = ok ? 'connected' : 'error';
      if (!ok) {
        _error = 'Failed to send monthly report state';
      }
      notifyListeners();
      return ok;
    } catch (error) {
      _error = error.toString();
      _status = 'error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendReportReset(DateTime resetAt) async {
    if (!_socketService.isConnected) {
      _error = 'No active connection';
      _status = 'offline';
      notifyListeners();
      return false;
    }

    try {
      _status = 'syncing';
      _error = null;
      notifyListeners();
      final ok = await _socketService.sendReportReset(resetAt);
      _status = ok ? 'connected' : 'error';
      if (!ok) {
        _error = 'Failed to send report reset';
      }
      notifyListeners();
      return ok;
    } catch (error) {
      _error = error.toString();
      _status = 'error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendMonthlyReportReset(DateTime resetAt) async {
    if (!_socketService.isConnected) {
      _error = 'No active connection';
      _status = 'offline';
      notifyListeners();
      return false;
    }

    try {
      _status = 'syncing';
      _error = null;
      notifyListeners();
      final ok = await _socketService.sendMonthlyReportReset(resetAt);
      _status = ok ? 'connected' : 'error';
      if (!ok) {
        _error = 'Failed to send monthly report reset';
      }
      notifyListeners();
      return ok;
    } catch (error) {
      _error = error.toString();
      _status = 'error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendMenuSync(List<MenuItem> items) async {
    if (!_socketService.isConnected) {
      _error = 'No active connection';
      _status = 'offline';
      notifyListeners();
      return false;
    }

    try {
      _status = 'syncing';
      _error = null;
      notifyListeners();

      var ok = false;
      for (var attempt = 0; attempt < 3 && !ok; attempt++) {
        ok = await _socketService.sendMenuSync(items);
        if (!ok && attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }

      _status = ok ? 'connected' : 'error';
      if (!ok) {
        _error = 'Failed to sync menu';
      }
      notifyListeners();
      return ok;
    } catch (error) {
      _error = error.toString();
      _status = 'error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendQrSync(
      {String? path, String? base64, String? mimeType, String? gcashNumber}) async {
    if (!_socketService.isConnected) {
      return false;
    }

    try {
      return await _socketService.sendQrSync(
          path: path, base64: base64, mimeType: mimeType, gcashNumber: gcashNumber);
    } catch (error) {
      _error = error.toString();
      _status = 'error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> syncInventoryToPeers() async {
    if (!_socketService.isConnected) {
      return false;
    }

    try {
      return await _socketService.sendInventorySync();
    } catch (error) {
      _error = error.toString();
      _status = 'error';
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    _userRequestedDisconnect = true;
    _socketService.setAutoReconnect(false);
    await _socketService.disconnect();
    _status = 'idle';
    _error = null;
    _connectedPeers.clear();
    notifyListeners();
  }

  Future<void> stop() async {
    _userRequestedDisconnect = true;
    _socketService.setAutoReconnect(false);
    await _socketService.stopServer();
    await _socketService.disconnect();
    _status = 'idle';
    _error = null;
    _connectedPeers.clear();
    // clear server flag when stopped
    _isServer = false;
    notifyListeners();
  }

  Future<void> _saveReceivedOrder(Order order,
      {bool deductInventory = false}) async {
    try {
      final id = order.id.isNotEmpty ? order.id : _uuid.v4();
      final orderToSave = order.copyWith(id: id);
      final orderService = OrderService();
      await orderService.saveOrder(
        orderToSave,
        deductInventory: deductInventory,
        isServerRole: _isServer,
      );
      if (deductInventory) {
        await syncInventoryToPeers();
      }
    } catch (error) {
      // Ignore persistence failures for received orders.
    }
  }

  @override
  void dispose() {
    _receivedSubscription?.cancel();
    _statusSubscription?.cancel();
    _errorSubscription?.cancel();
    _peersSubscription?.cancel();
    _reportResetSubscription?.cancel();
    _socketService.dispose();
    super.dispose();
  }
}
