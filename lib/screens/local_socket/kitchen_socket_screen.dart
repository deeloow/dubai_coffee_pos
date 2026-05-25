import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/local_order_socket_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class KitchenSocketScreen extends StatefulWidget {
  const KitchenSocketScreen({super.key});

  @override
  State<KitchenSocketScreen> createState() => _KitchenSocketScreenState();
}

class _KitchenSocketScreenState extends State<KitchenSocketScreen> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '4567');
  bool _connecting = false;

  Future<void> _connect(LocalOrderSocketProvider provider) async {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the cashier device IP address.')),
      );
      return;
    }
    final port = int.tryParse(_portController.text.trim()) ?? 4567;
    setState(() => _connecting = true);
    await provider.connect(host, port: port);
    setState(() => _connecting = false);
  }

  Future<void> _disconnect(LocalOrderSocketProvider provider) async {
    await provider.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kitchen Socket Client')),
      backgroundColor: AppColors.cream,
      body: Consumer<LocalOrderSocketProvider>(
        builder: (context, provider, _) {
          final status = provider.status;
          final peers = provider.connectedPeers;
          final lastOrder = provider.lastReceivedOrder;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppText('Kitchen Receiver', size: 15, weight: FontWeight.w700),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Cashier Host IP',
                        hintText: 'e.g. 192.168.43.1',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Port'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _connecting ? null : () => _connect(provider),
                            child: const Text('Connect'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: provider.isConnected ? () => _disconnect(provider) : null,
                            child: const Text('Disconnect'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StatusRow(label: 'Connection', value: status),
                    const SizedBox(height: 8),
                    _StatusRow(label: 'Connected Host', value: provider.host),
                    const SizedBox(height: 8),
                    _StatusRow(label: 'Active link', value: peers.isNotEmpty ? peers.join(', ') : 'None'),
                    if (provider.error != null) ...[
                      const SizedBox(height: 12),
                      Text(provider.error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (lastOrder != null)
                SectionCard(
                  color: AppColors.bgLight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppText('Last Received Order', size: 15, weight: FontWeight.w700),
                      const SizedBox(height: 10),
                      Text('Order #${lastOrder.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Table: ${lastOrder.customerName}'),
                      Text('Items: ${lastOrder.items.map((item) => '${item.qty}× ${item.name}').join(', ')}'),
                      Text('Status: ${lastOrder.statusLabel}'),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppText('Received Orders', size: 15, weight: FontWeight.w700),
                    const SizedBox(height: 12),
                    if (provider.receivedOrders.isEmpty)
                      const AppText('No orders received yet.', size: 13, color: AppColors.textMuted)
                    else
                      ...provider.receivedOrders.map(
                        (order) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderColor, width: 0.5),
                              color: AppColors.white,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Order #${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(order.customerName),
                                const SizedBox(height: 4),
                                Text(order.items.map((item) => '${item.qty}× ${item.name}').join(', ')),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppText(label, size: 12, weight: FontWeight.w600, color: AppColors.textMuted),
        const Spacer(),
        AppText(value, size: 12, weight: FontWeight.w500),
      ],
    );
  }
}
