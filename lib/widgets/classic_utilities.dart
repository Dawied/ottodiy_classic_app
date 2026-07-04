import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import '../utils/download_helper.dart';
import 'small_button.dart';
import 'calibration_dialog.dart';

class ClassicUtilities extends StatelessWidget {
  final BluetoothManager btManager;

  const ClassicUtilities({super.key, required this.btManager});

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
            Opacity(
              opacity: isConnected ? 1.0 : 0.4,
              child: AbsorbPointer(
                absorbing: !isConnected,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SmallButton(
                      btManager.lastDistance != null
                          ? 'Distance: ${btManager.lastDistance!.toStringAsFixed(0)} cm'
                          : 'Distance',
                      Icons.sensors,
                      Colors.tealAccent,
                      () => btManager.toggleUltrasoundPolling(),
                      isActive: btManager.isPollingUltrasound,
                    ),
                    SmallButton(
                      'Walk Test',
                      Icons.directions_walk,
                      Colors.pinkAccent,
                      () => btManager.sendCommand('walk_test2\n'),
                    ),
                    SmallButton(
                      'Calibrate',
                      Icons.build,
                      Colors.orangeAccent,
                      () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) =>
                              CalibrationDialog(btManager: btManager),
                        );
                      },
                    ),
                    SmallButton(
                      'Get Arduino Code',
                      Icons.download,
                      Colors.lightBlueAccent,
                      () {
                        DownloadHelper.downloadFile(
                          'https://github.com/Dawied/ottodiy_classic_app/blob/main/firmware/OttoS_BLE_v2/OttoS_BLE_v2.ino',
                          'OttoS_BLE_v2.ino',
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
              ),
            ),
          ],
        );
      },
    );
  }
}
