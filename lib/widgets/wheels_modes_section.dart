import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import 'control_button.dart';

class WheelsModesSection extends StatelessWidget {
  final BluetoothManager btManager;

  const WheelsModesSection({super.key, required this.btManager});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: btManager,
      builder: (context, _) {
        final isConnected = btManager.connectedDevice != null;
        return Opacity(
          opacity: isConnected ? 1.0 : 0.4,
          child: AbsorbPointer(
            absorbing: !isConnected,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'MODES',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          ControlButton(
                            icon: Icons.remove_red_eye,
                            label: 'AVOIDANCE',
                            color: Colors.lightGreenAccent,
                            isActive: btManager.activeMode == 'avoidance',
                            onPressed: () {
                              if (btManager.activeMode == 'avoidance') {
                                btManager.sendCommand(
                                  'stop${btManager.speedIndex}\n',
                                );
                              } else {
                                btManager.sendCommand(
                                  'avoidance${btManager.speedIndex}\n',
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Otto starts driving and avoids obstacles',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          ControlButton(
                            icon: Icons.navigation,
                            label: 'LINE FOLLOWER',
                            color: Colors.lightBlueAccent,
                            isActive: btManager.activeMode == 'line_follower',
                            onPressed: () {
                              if (btManager.activeMode == 'line_follower') {
                                btManager.sendCommand(
                                  'stop${btManager.speedIndex}\n',
                                );
                              } else {
                                btManager.sendCommand(
                                  'line_follower${btManager.speedIndex}\n',
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Otto follows lines on the ground',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
