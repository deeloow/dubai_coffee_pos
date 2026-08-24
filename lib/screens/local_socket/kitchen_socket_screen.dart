import 'dart:io';

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

    final address = InternetAddress.tryParse(host);
    if (address == null || address.type != InternetAddressType.IPv4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid IPv4 address.')),
      );
      return;
    }

    final port = int.tryParse(_portController.text.trim()) ?? 4567;
    if (port <= 0 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid port between 1 and 65535.')),
      );
      return;
    }

    setState(() => _connecting = true);
    await provider.connect(host, port: port);
    setState(() => _connecting = false);
  }

  Future<void> _disconnect(LocalOrderSocketProvider provider) async {
    await provider.disconnect();
  }

  // Recent hosts removed; user must enter host manually.

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Kitchen Socket Client')),
      backgroundColor: AppColors.cream,
      body: Consumer<LocalOrderSocketProvider>(
        builder: (context, provider, _) {
          final peers = provider.connectedPeers;
          final showReconnectBadge = provider.shouldAutoReconnect && !provider.isConnected;

          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppText('Kitchen Receiver', size: 15, weight: FontWeight.w700),
                    const SizedBox(height: 12),
                    const SizedBox.shrink(),
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
                            onPressed: provider.isConnected || provider.shouldAutoReconnect
                                ? () => _disconnect(provider)
                                : null,
                            child: const Text('Disconnect'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StatusRow(label: 'Connection', value: provider.connectionState),
                    const SizedBox(height: 8),
                    if (showReconnectBadge) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: provider.status == 'reconnecting'
                              ? const Color(0xFFFFF4E5)
                              : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: provider.status == 'reconnecting'
                                ? Colors.orange.shade400
                                : Colors.green.shade400,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (provider.status == 'reconnecting')
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Icon(Icons.link, size: 14, color: Colors.green.shade700),
                            const SizedBox(width: 6),
                            Text(
                              provider.status == 'reconnecting'
                                  ? 'Reconnecting…'
                                  : 'Auto-reconnect enabled',
                              style: TextStyle(
                                fontSize: 12,
                                color: provider.status == 'reconnecting'
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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
