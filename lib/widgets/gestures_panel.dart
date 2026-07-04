import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import 'small_button.dart';

class GesturesPanel extends StatelessWidget {
  final BluetoothManager btManager;

  const GesturesPanel({super.key, required this.btManager});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'GESTURES',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 10,
          children: [
            SmallButton(
              'Happy',
              Icons.mood,
              Colors.amber,
              () => btManager.sendCommand('happy2\n'),
            ),
            SmallButton(
              'Victory',
              Icons.emoji_events,
              Colors.amber,
              () => btManager.sendCommand('victory2\n'),
            ),
            SmallButton(
              'Sad',
              Icons.mood_bad,
              Colors.amber,
              () => btManager.sendCommand('sad2\n'),
            ),
            SmallButton(
              'Sleep',
              Icons.hotel,
              Colors.amber,
              () => btManager.sendCommand('sleeping2\n'),
            ),
            SmallButton(
              'Confused',
              Icons.question_mark,
              Colors.amber,
              () => btManager.sendCommand('confused2\n'),
            ),
            SmallButton(
              'Fail',
              Icons.error_outline,
              Colors.amber,
              () => btManager.sendCommand('fail2\n'),
            ),
            SmallButton(
              'Fart',
              Icons.air,
              Colors.amber,
              () => btManager.sendCommand('fart2\n'),
            ),
            SmallButton(
              'Love',
              Icons.favorite,
              Colors.amber,
              () => btManager.sendCommand('love2\n'),
            ),
            SmallButton(
              'Fretful',
              Icons.warning_amber_rounded,
              Colors.amber,
              () => btManager.sendCommand('fretful2\n'),
            ),
            SmallButton(
              'Magic',
              Icons.auto_awesome,
              Colors.amber,
              () => btManager.sendCommand('magic2\n'),
            ),
          ],
        ),
      ],
    );
  }
}
