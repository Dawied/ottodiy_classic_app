import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import 'drive_section.dart';
import 'wheels_modes_section.dart';
import 'wheels_utilities.dart';

class WheelsTab extends StatelessWidget {
  final BluetoothManager btManager;

  const WheelsTab({super.key, required this.btManager});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DriveSection(btManager: btManager),
          const SizedBox(height: 24),
          WheelsModesSection(btManager: btManager),
          const SizedBox(height: 24),
          const WheelsUtilities(),
        ],
      ),
    );
  }
}
