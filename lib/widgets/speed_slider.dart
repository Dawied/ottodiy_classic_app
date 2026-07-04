import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';

class SpeedSlider extends StatelessWidget {
  final BluetoothManager btManager;

  const SpeedSlider({super.key, required this.btManager});

  String _getSpeedLabel(int index) {
    switch (index) {
      case 0:
        return 'Very Slow (3.0s)';
      case 1:
        return 'Slow (2.0s)';
      case 2:
        return 'Normal (1.0s)';
      case 3:
        return 'Fast (0.75s)';
      case 4:
        return 'Very Fast (0.5s)';
      case 5:
        return 'Turbo (0.25s)';
      default:
        return 'Normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: btManager,
      builder: (context, _) {
        return SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.speed, color: Colors.grey, size: 20),
              const SizedBox(height: 4),
              const Text(
                'SPEED',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getSpeedLabel(btManager.speedIndex),
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Slider(
                    value: btManager.speedIndex.toDouble(),
                    min: 0,
                    max: 5,
                    divisions: 5,
                    activeColor: const Color(0xFF00E5FF),
                    inactiveColor: Colors.white10,
                    onChanged: (value) {
                      btManager.speedIndex = value.round();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
