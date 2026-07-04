import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import 'small_button.dart';
import 'virtual_joystick.dart';
import 'dpad_controls.dart';
import 'speed_slider.dart';

class DriveSection extends StatefulWidget {
  final BluetoothManager btManager;

  const DriveSection({super.key, required this.btManager});

  @override
  State<DriveSection> createState() => _DriveSectionState();
}

class _DriveSectionState extends State<DriveSection> {
  bool _useAnalogJoystick = true;
  DateTime? _lastJoystickSendTime;

  void _sendJoystickCommand(double x, double y) {
    final now = DateTime.now();
    if (_lastJoystickSendTime == null ||
        now.difference(_lastJoystickSendTime!) >
            const Duration(milliseconds: 100)) {
      _lastJoystickSendTime = now;
      widget.btManager.sendCommand('J${x.round()},${y.round()}H\n');
    }
  }

  void _stopJoystick() {
    widget.btManager.sendCommand('J0,0H\n');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.btManager,
      builder: (context, _) {
        final isConnected = widget.btManager.connectedDevice != null;
        return Opacity(
          opacity: isConnected ? 1.0 : 0.4,
          child: AbsorbPointer(
            absorbing: !isConnected,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DRIVE',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Row(
                      children: [
                        SmallButton(
                          'Joystick',
                          Icons.circle_outlined,
                          _useAnalogJoystick
                              ? const Color(0xFF00E5FF)
                              : Colors.grey,
                          () => setState(() => _useAnalogJoystick = true),
                          isActive: _useAnalogJoystick,
                        ),
                        const SizedBox(width: 8),
                        SmallButton(
                          'D-Pad',
                          Icons.grid_3x3,
                          _useAnalogJoystick
                              ? Colors.grey
                              : const Color(0xFF00E5FF),
                          () => setState(() => _useAnalogJoystick = false),
                          isActive: !_useAnalogJoystick,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_useAnalogJoystick)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: VirtualJoystick(
                        onJoystickChanged: _sendJoystickCommand,
                        onJoystickStop: _stopJoystick,
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      DpadControls(btManager: widget.btManager),
                      const SizedBox(
                        width: 40,
                      ), // Spacing between joystick and slider
                      SpeedSlider(btManager: widget.btManager),
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
