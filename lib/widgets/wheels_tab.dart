import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import 'drive_section.dart';
import 'wheels_modes_section.dart';
import 'wheels_utilities.dart';
import 'songs_panel.dart';

class WheelsTab extends StatelessWidget {
  final BluetoothManager btManager;

  const WheelsTab({super.key, required this.btManager});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: btManager,
      builder: (context, _) {
        final isConnected = btManager.connectedDevice != null;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DriveSection(btManager: btManager),
              const SizedBox(height: 24),
              Opacity(
                opacity: isConnected ? 1.0 : 0.4,
                child: AbsorbPointer(
                  absorbing: !isConnected,
                  child: SongsPanel(btManager: btManager, title: 'SOUNDS'),
                ),
              ),
              const SizedBox(height: 24),
              WheelsModesSection(btManager: btManager),
              const SizedBox(height: 24),
              const WheelsUtilities(),
            ],
          ),
        );
      },
    );
  }
}
