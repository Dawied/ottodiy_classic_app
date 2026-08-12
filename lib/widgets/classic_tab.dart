import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import 'walk_section.dart';
import 'gestures_panel.dart';
import 'songs_panel.dart';
import 'classic_modes_section.dart';
import 'classic_utilities.dart';

class ClassicTab extends StatelessWidget {
  final BluetoothManager btManager;

  const ClassicTab({super.key, required this.btManager});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: btManager,
      builder: (context, _) {
        final isConnected = btManager.connectedDevice != null;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Opacity(
                opacity: isConnected ? 1.0 : 0.4,
                child: AbsorbPointer(
                  absorbing: !isConnected,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WalkSection(btManager: btManager),
                      const SizedBox(height: 6),
                      GesturesPanel(btManager: btManager),
                      const SizedBox(height: 6),
                      SongsPanel(btManager: btManager),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ClassicModesSection(btManager: btManager),
              const SizedBox(height: 16),
              ClassicUtilities(btManager: btManager),
            ],
          ),
        );
      },
    );
  }
}
