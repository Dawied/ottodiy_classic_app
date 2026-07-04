import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import 'joystick_button.dart';

class DpadControls extends StatelessWidget {
  final BluetoothManager btManager;

  const DpadControls({super.key, required this.btManager});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Up
        JoystickButton(
          icon: Icons.keyboard_arrow_up,
          color: const Color(0xFF00E5FF),
          onPressed: () =>
              btManager.sendCommand('forward${btManager.speedIndex}\n'),
        ),
        const SizedBox(height: 8),
        // Middle Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            JoystickButton(
              icon: Icons.keyboard_arrow_left,
              color: const Color(0xFF00E5FF),
              onPressed: () =>
                  btManager.sendCommand('left${btManager.speedIndex}\n'),
            ),
            const SizedBox(width: 8),
            JoystickButton(
              icon: Icons.stop_circle_outlined,
              color: Colors.redAccent,
              isCenter: true,
              onPressed: () =>
                  btManager.sendCommand('stop${btManager.speedIndex}\n'),
            ),
            const SizedBox(width: 8),
            JoystickButton(
              icon: Icons.keyboard_arrow_right,
              color: const Color(0xFF00E5FF),
              onPressed: () =>
                  btManager.sendCommand('right${btManager.speedIndex}\n'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Down
        JoystickButton(
          icon: Icons.keyboard_arrow_down,
          color: const Color(0xFF00E5FF),
          onPressed: () =>
              btManager.sendCommand('backward${btManager.speedIndex}\n'),
        ),
      ],
    );
  }
}
