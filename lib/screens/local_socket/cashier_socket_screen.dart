import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/local_order_socket_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class CashierSocketScreen extends StatefulWidget {
  const CashierSocketScreen({super.key});

  @override
  State<CashierSocketScreen> createState() => _CashierSocketScreenState();
}

class _CashierSocketScreenState extends State<CashierSocketScreen> {
  final TextEditingController _portController = TextEditingController(text: '4567');

  bool _startingServer = false;

  Future<void> _toggleServer(LocalOrderSocketProvider provider) async {
    if (provider.isServer) {
      setState(() => _startingServer = true);
      await provider.stop();
      setState(() => _startingServer = false);
      return;
    }

    final port = int.tryParse(_portController.text) ?? 4567;
    setState(() => _startingServer = true);
    await provider.startServer(port: port);
    setState(() => _startingServer = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cashier Hotspot Server')),
      backgroundColor: AppColors.cream,
      body: Consumer<LocalOrderSocketProvider>(
        builder: (context, provider, _) {
          final isServer = provider.isServer;
          final status = provider.status;
          final connectedClients = provider.connectedPeers.length;
          final address = provider.localAddress;
          final port = provider.port;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppText('Local Socket Host', size: 15, weight: FontWeight.w700),
                    const SizedBox(height: 12),
                    _StatusRow(label: 'Mode', value: isServer ? 'Server' : 'Standby'),
                    const SizedBox(height: 8),
                    _StatusRow(label: 'Server IP', value: address),
                    const SizedBox(height: 8),
                    _StatusRow(label: 'Port', value: port.toString()),
                    const SizedBox(height: 8),
                    _StatusRow(label: 'Status', value: status),
                    const SizedBox(height: 8),
                    _StatusRow(label: 'Connected kitchen clients', value: '$connectedClients'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _startingServer ? null : () => _toggleServer(provider),
                        child: Text(isServer ? 'Stop Server' : 'Start Server'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    AppText('Automatic Order Sync', size: 15, weight: FontWeight.w700),
                    SizedBox(height: 12),
                    AppText(
                      'Orders from the cashier POS are sent automatically to the connected kitchen device when the hotspot server is active.',
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(height: 12),
                    AppText(
                      'Keep this screen open and connected; then confirm the order from the cashier section.',
                      size: 12,
                      color: AppColors.textMuted,
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
