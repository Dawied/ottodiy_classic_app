import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';

class ConnectionModal extends StatefulWidget {
  final BluetoothManager btManager;

  const ConnectionModal({super.key, required this.btManager});

  @override
  State<ConnectionModal> createState() => _ConnectionModalState();
}

class _ConnectionModalState extends State<ConnectionModal> {
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    widget.btManager.addListener(_connectionListener);
  }

  @override
  void dispose() {
    widget.btManager.removeListener(_connectionListener);
    super.dispose();
  }

  void _connectionListener() async {
    if (!_isClosing && widget.btManager.connectedDevice != null && mounted) {
      _isClosing = true;
      widget.btManager.removeListener(_connectionListener);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.btManager,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Otto DIY Connection',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.grey, thickness: 0.5),
              const SizedBox(height: 10),

              // Scan status
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.btManager.isScanning
                      ? Colors.redAccent.withValues(alpha: 0.2)
                      : const Color(0xFF00E5FF),
                  foregroundColor: widget.btManager.isScanning
                      ? Colors.redAccent
                      : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: widget.btManager.isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.redAccent,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  widget.btManager.isScanning
                      ? 'Scanning... Stop'
                      : 'Scan for Otto Robots',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  if (widget.btManager.isScanning) {
                    widget.btManager.stopScan();
                  } else {
                    widget.btManager.startScan();
                  }
                },
              ),
              const SizedBox(height: 15),

              if (widget.btManager.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    widget.btManager.errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              ],

              // Connection progress
              if (widget.btManager.isConnecting) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xFF00E5FF)),
                        SizedBox(height: 12),
                        Text(
                          'Connecting to Otto DIY...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Discovered devices list
                const Text(
                  'Discovered Devices',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: widget.btManager.devices.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Text(
                              'No devices found yet. Tap Scan.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: widget.btManager.devices.length,
                          itemBuilder: (context, index) {
                            final dev = widget.btManager.devices[index];
                            final isConnected =
                                widget.btManager.connectedDevice?.id == dev.id;

                            return Card(
                              color: const Color(0xFF1F2937),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                onTap: () {
                                  if (isConnected) {
                                    widget.btManager.disconnect();
                                  } else {
                                    widget.btManager.connect(dev);
                                  }
                                },
                                leading: CircleAvatar(
                                  backgroundColor: isConnected
                                      ? const Color(
                                          0xFF00E5FF,
                                        ).withValues(alpha: 0.2)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  child: Icon(
                                    Icons.smart_toy,
                                    color: isConnected
                                        ? const Color(0xFF00E5FF)
                                        : Colors.white70,
                                  ),
                                ),
                                title: Text(
                                  dev.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'ID: ${dev.id} | RSSI: ${dev.rssi} dBm',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isConnected
                                        ? Colors.redAccent
                                        : const Color(0xFF00E5FF),
                                    foregroundColor: isConnected
                                        ? Colors.white
                                        : Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (isConnected) {
                                      widget.btManager.disconnect();
                                    } else {
                                      widget.btManager.connect(dev);
                                    }
                                  },
                                  child: Text(
                                    isConnected ? 'Disconnect' : 'Connect',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
