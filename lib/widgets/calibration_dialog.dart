import 'dart:async';
import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';

class CalibrationDialog extends StatefulWidget {
  final BluetoothManager btManager;

  const CalibrationDialog({super.key, required this.btManager});

  @override
  State<CalibrationDialog> createState() => CalibrationDialogState();
}

class CalibrationDialogState extends State<CalibrationDialog> {
  int _ll = 90;
  int _rl = 90;
  int _lf = 90;
  int _rf = 90;
  Timer? _debounceTimer;
  final Map<String, int> _pendingTrims = {};

  @override
  void initState() {
    super.initState();
    // Force the robot to zero trims (90 degrees) to perfectly sync with the UI.
    // This is required because the Arduino sketch does not provide a way to read
    // existing trims, and adjusting one trim via Bluetooth resets the others to 0 in RAM.
    widget.btManager.sendCommand("C90a90b90c90d\n");
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _updateTrim(
    String motor,
    int currentVal,
    int delta,
    Function(int) updater,
  ) {
    int newVal = currentVal + delta;
    if (newVal < 0) newVal = 0;
    if (newVal > 180) newVal = 180;

    updater(newVal);
    _pendingTrims[motor] = newVal;

    _debounceTimer?.cancel();
    // Wait 300ms after the last tap before sending commands. Since the Arduino
    // now uses a smooth 500ms blocking movement, sending updates immediately
    // on every tap queues up multiple 500ms movements and causes jerky stuttering.
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _pendingTrims.forEach((m, val) {
        widget.btManager.sendCommand("C$val$m\n");
      });
      _pendingTrims.clear();
    });
  }

  Widget _buildTrimRow(
    String label,
    String motor,
    int value,
    Function(int) updater,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.redAccent,
                ),
                onPressed: () => _updateTrim(motor, value, -1, updater),
              ),
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  value.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.greenAccent,
                ),
                onPressed: () => _updateTrim(motor, value, 1, updater),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Calibration', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTrimRow('Left Leg', 'a', _ll, (v) => setState(() => _ll = v)),
          _buildTrimRow('Right Leg', 'b', _rl, (v) => setState(() => _rl = v)),
          _buildTrimRow('Left Foot', 'c', _lf, (v) => setState(() => _lf = v)),
          _buildTrimRow('Right Foot', 'd', _rf, (v) => setState(() => _rf = v)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            if (_debounceTimer?.isActive ?? false) {
              _debounceTimer?.cancel();
              _pendingTrims.forEach((m, val) {
                widget.btManager.sendCommand("C$val$m\n");
              });
              _pendingTrims.clear();
            }
            widget.btManager.sendCommand("save_calibration\n");
            Navigator.of(context).pop();
          },
          child: const Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
