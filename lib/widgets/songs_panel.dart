import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import 'small_button.dart';

class SongsPanel extends StatelessWidget {
  final BluetoothManager btManager;

  const SongsPanel({super.key, required this.btManager});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'SING',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SmallButton(
              'Surprise',
              Icons.music_note,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 6\n'),
            ),
            SmallButton(
              'OhOoh',
              Icons.music_note,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 7\n'),
            ),
            SmallButton(
              'OhOoh 2',
              Icons.music_note,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 8\n'),
            ),
            SmallButton(
              'Cuddly',
              Icons.music_note,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 9\n'),
            ),
            SmallButton(
              'Sleeping',
              Icons.music_note,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 10\n'),
            ),
            SmallButton(
              'Happy',
              Icons.music_note,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 12\n'),
            ),
            SmallButton(
              'Sad',
              Icons.music_note,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 14\n'),
            ),
            SmallButton(
              'Confused',
              Icons.music_note,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 15\n'),
            ),
            SmallButton(
              'Fart',
              Icons.music_note,
              const Color(0xFFFFB300),
              () => btManager.sendCommand('sing 17\n'),
            ),
          ],
        ),
      ],
    );
  }
}
