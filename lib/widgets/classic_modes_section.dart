import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import 'control_button.dart';

class ClassicModesSection extends StatelessWidget {
  final BluetoothManager btManager;

  const ClassicModesSection({super.key, required this.btManager});

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
                            'Otto starts walking and avoids obstacles',
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
                            icon: Icons.sports_martial_arts,
                            label: 'USE FORCE',
                            color: Colors.lightBlueAccent,
                            isActive: btManager.activeMode == 'force',
                            onPressed: () {
                              if (btManager.activeMode == 'force') {
                                btManager.sendCommand(
                                  'stop${btManager.speedIndex}\n',
                                );
                              } else {
                                btManager.sendCommand(
                                  'force${btManager.speedIndex}\n',
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Move your hand in front of Otto to have it react to it',
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
