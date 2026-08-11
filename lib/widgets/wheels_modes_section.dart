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
                                  'avoidance_dist${btManager.avoidanceDistance}\n',
                                );
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
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Trigger Dist:',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${btManager.avoidanceDistance} cm',
                                      style: const TextStyle(
                                        color: Colors.lightGreenAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 12,
                                    ),
                                    activeTrackColor: Colors.lightGreenAccent,
                                    inactiveTrackColor: Colors.white10,
                                    thumbColor: Colors.lightGreenAccent,
                                  ),
                                  child: Slider(
                                    value:
                                        btManager.avoidanceDistance.toDouble(),
                                    min: 5.0,
                                    max: 40.0,
                                    divisions: 35,
                                    onChanged: (val) {
                                      btManager.setAvoidanceDistance(
                                        val.round(),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
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
