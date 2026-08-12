import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import 'small_button.dart';

class SongsPanel extends StatelessWidget {
  final BluetoothManager btManager;
  final String title;

  const SongsPanel({super.key, required this.btManager, this.title = 'SING'});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            SmallButton(
              'Surprise',
              null,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 6\n'),
            ),
            SmallButton(
              'OhOoh',
              null,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 7\n'),
            ),
            SmallButton(
              'Cuddly',
              null,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 9\n'),
            ),
            SmallButton(
              'Sad',
              null,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 14\n'),
            ),
            SmallButton(
              'Sleeping',
              null,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 10\n'),
            ),
            SmallButton(
              'Happy',
              null,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 12\n'),
            ),
            SmallButton(
              'Confused',
              null,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 15\n'),
            ),
            SmallButton(
              'Fart',
              null,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 17\n'),
            ),
          ],
        ),
      ],
    );
  }
}
