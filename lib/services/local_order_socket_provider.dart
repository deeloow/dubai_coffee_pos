import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'local_order_socket_service.dart';
import 'order_service.dart';

class LocalOrderSocketProvider extends ChangeNotifier {
  final LocalOrderSocketService _socketService = LocalOrderSocketService();
  final Uuid _uuid = const Uuid();

  bool _initialized = false;
  bool _isServer = false;
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
        await _saveReceivedOrder(order, deductInventory: false);
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
        _error = null;
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
    try {
      _status = 'starting';
      _error = null;
      notifyListeners();
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
    try {
      _isServer = false;
      _status = 'connecting';
      _error = null;
      _host = host;
      _port = port;
      notifyListeners();
      await _socketService.connectToHost(host, port: port);
      _status = 'connected';
      _error = null;
      notifyListeners();
      return true;
    } catch (error) {
      _error = error.toString();
      _status = 'error';
      notifyListeners();
      return false;
    }
  }

  Future<void> resumeConnection() async {
    if (_isServer || !_socketService.autoReconnect || _host.isEmpty) {
      return;
    }
    if (_socketService.isConnected) {
      return;
    }
    try {
      _status = 'reconnecting';
      _error = null;
      notifyListeners();
      await _socketService.connectToHost(_host, port: _port);
      _status = 'connected';
      _error = null;
      notifyListeners();
    } catch (_) {
      _status = 'reconnecting';
      notifyListeners();
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

  Future<void> disconnect() async {
    await _socketService.disconnect();
    _status = 'idle';
    _error = null;
    _connectedPeers.clear();
    notifyListeners();
  }

  Future<void> stop() async {
    await _socketService.stopServer();
    await _socketService.disconnect();
    _status = 'idle';
    _error = null;
    _connectedPeers.clear();
    // clear server flag when stopped
    _isServer = false;
    notifyListeners();
  }

  Future<void> _saveReceivedOrder(Order order, {bool deductInventory = false}) async {
    try {
      final id = order.id.isNotEmpty ? order.id : _uuid.v4();
      final orderToSave = order.copyWith(id: id);
      final orderService = OrderService();
      await orderService.saveOrder(orderToSave, deductInventory: deductInventory);
    } catch (error) {
      // Ignore persistence failures for received orders.
    }
  }

  @override
  void dispose() {
    _receivedSubscription?.cancel();
    _statusSubscription?.cancel();
    _peersSubscription?.cancel();
    _reportResetSubscription?.cancel();
    _socketService.dispose();
    super.dispose();
  }
}
