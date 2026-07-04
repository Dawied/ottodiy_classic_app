import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';

class ConsolePanel extends StatelessWidget {
  final BluetoothManager btManager;
  final VoidCallback onClose;

  const ConsolePanel({
    super.key,
    required this.btManager,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CONSOLE LOGS',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, color: Colors.grey, size: 16),
                    onPressed: onClose,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              itemCount: btManager.consoleLogs.length,
              itemBuilder: (context, index) {
                final log = btManager.consoleLogs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    log,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF34D399), // terminal green
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
