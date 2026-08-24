import 'package:flutter_test/flutter_test.dart';
import 'package:dubai_coffee_pos/services/local_order_socket_provider.dart';
import 'package:dubai_coffee_pos/services/local_order_socket_service.dart';

void main() {
  group('LocalOrderSocketProvider reconnect behavior', () {
    test('reflects the socket service auto-reconnect flag', () async {
      final service = LocalOrderSocketService();
      final provider = LocalOrderSocketProvider(socketService: service);

      service.setAutoReconnect(true);
      expect(provider.shouldAutoReconnect, isTrue);

      await provider.disconnect();
      expect(provider.shouldAutoReconnect, isFalse);
    });
  });
}
