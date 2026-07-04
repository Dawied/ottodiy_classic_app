import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import 'dpad_controls.dart';
import 'speed_slider.dart';

class WalkSection extends StatelessWidget {
  final BluetoothManager btManager;

  const WalkSection({super.key, required this.btManager});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'WALK',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        // Joystick and Speed Slider Side-by-Side
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DpadControls(btManager: btManager),
            const SizedBox(width: 40), // Spacing between joystick and slider
            SpeedSlider(btManager: btManager),
          ],
        ),
      ],
    );
  }
}
