import 'package:flutter/material.dart';
import '../utils/download_helper.dart';
import 'small_button.dart';

class WheelsUtilities extends StatelessWidget {
  const WheelsUtilities({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'UTILITIES',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SmallButton(
              'Get Arduino Code',
              Icons.download,
              Colors.lightBlueAccent,
              () {
                DownloadHelper.downloadFile(
                  'https://github.com/Dawied/ottodiy_classic_app/blob/main/firmware/OttoW_BLE_v2/OttoW_BLE_v2.ino',
                  'OttoW_BLE_v2.ino',
                ).catchError((e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Download failed: $e')),
                    );
                  }
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}
