import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import '../utils/download_helper.dart';
import 'small_button.dart';

class WheelsUtilities extends StatelessWidget {
  final BluetoothManager btManager;

  const WheelsUtilities({super.key, required this.btManager});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: btManager,
      builder: (context, _) {
        final isConnected = btManager.connectedDevice != null;
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
                Opacity(
                  opacity: isConnected ? 1.0 : 0.4,
                  child: AbsorbPointer(
                    absorbing: !isConnected,
                    child: SmallButton(
                      btManager.lastDistance != null
                          ? 'Distance: ${btManager.lastDistance!.toStringAsFixed(0)} cm'
                          : 'Distance',
                      Icons.sensors,
                      Colors.tealAccent,
                      () => btManager.toggleUltrasoundPolling(),
                      isActive: btManager.isPollingUltrasound,
                    ),
                  ),
                ),
                Opacity(
                  opacity: isConnected ? 1.0 : 0.4,
                  child: AbsorbPointer(
                    absorbing: !isConnected,
                    child: SmallButton(
                      btManager.lineSensorLabel,
                      Icons.alt_route,
                      Colors.purpleAccent,
                      () => btManager.toggleLineSensorPolling(),
                      isActive: btManager.isPollingLineSensor,
                    ),
                  ),
                ),
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
      },
    );
  }
}
