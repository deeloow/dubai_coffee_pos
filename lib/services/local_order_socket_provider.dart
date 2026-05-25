import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'local_order_socket_service.dart';

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

  bool get isServer => _isServer;
  bool get isConnected => _connectedPeers.isNotEmpty;
  String get status => _status;
  String? get error => _error;
  String get host => _host;
  int get port => _port;
  String get localAddress => _localAddress;
  List<String> get connectedPeers => List.unmodifiable(_connectedPeers);
  List<Order> get receivedOrders => List.unmodifiable(_receivedOrders);
  Order? get lastReceivedOrder => _lastReceivedOrder;

  void init() {
    if (_initialized) return;
    _initialized = true;
    _receivedSubscription = _socketService.receivedOrders.listen(
      (order) async {
        _lastReceivedOrder = order;
        _receivedOrders.insert(0, order);
        _status = 'received';
        _error = null;
        notifyListeners();
        await _saveReceivedOrder(order);
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
  }

  Future<bool> startServer({int port = 4567}) async {
    try {
      _isServer = true;
      _status = 'starting';
      _error = null;
      notifyListeners();
      await _socketService.startServer(port: port);
      _localAddress = _socketService.localAddress;
      _port = _socketService.port;
      _host = _localAddress;
      _status = 'listening';
      notifyListeners();
      return true;
    } catch (error) {
      _error = error.toString();
      _status = 'error';
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
    notifyListeners();
  }

  Future<void> _saveReceivedOrder(Order order) async {
    try {
      final box = Hive.box('orders');
      final id = order.id.isNotEmpty ? order.id : _uuid.v4();
      if (box.containsKey(id)) {
        return;
      }
      final orderMap = {
        ...order.toMap(),
        'id': id,
      };
      await box.put(id, orderMap);
    } catch (error) {
      // Ignore persistence failures for received orders.
    }
  }

  @override
  void dispose() {
    _receivedSubscription?.cancel();
    _statusSubscription?.cancel();
    _peersSubscription?.cancel();
    _socketService.dispose();
    super.dispose();
  }
}
