import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';

class WheelsCalibrationDialog extends StatefulWidget {
  final BluetoothManager btManager;

  const WheelsCalibrationDialog({super.key, required this.btManager});

  @override
  State<WheelsCalibrationDialog> createState() =>
      _WheelsCalibrationDialogState();
}

class _WheelsCalibrationDialogState extends State<WheelsCalibrationDialog> {
  int _leftTrim = 0;
  int _rightTrim = 0;
  bool _isContinuousDriving = false;
  bool _hasLoadedInitialCalib = false;

  @override
  void initState() {
    super.initState();
    widget.btManager.addListener(_onBtManagerChanged);
    Future.microtask(() {
      if (mounted) {
        if (widget.btManager.lastWheelCalib != null &&
            !_hasLoadedInitialCalib) {
          _parseCalibData(widget.btManager.lastWheelCalib!);
        }
        widget.btManager.sendCommand('wheel_calib_read\n');
      }
    });
  }

  @override
  void dispose() {
    widget.btManager.removeListener(_onBtManagerChanged);
    if (_isContinuousDriving) {
      widget.btManager.sendCommand('stop\n');
    }
    super.dispose();
  }

  void _onBtManagerChanged() {
    if (_hasLoadedInitialCalib) return;
    final calibStr = widget.btManager.lastWheelCalib;
    if (calibStr != null && mounted) {
      _parseCalibData(calibStr);
    }
  }

  void _parseCalibData(String str) {
    try {
      final parts = str.split(',');
      if (parts.length == 2) {
        final l = int.tryParse(parts[0].trim());
        final r = int.tryParse(parts[1].trim());
        if (l != null && r != null) {
          setState(() {
            _leftTrim = l.clamp(-30, 30);
            _rightTrim = r.clamp(-30, 30);
            _hasLoadedInitialCalib = true;
          });
        }
      }
    } catch (_) {}
  }

  void _sendTrimUpdate() {
    widget.btManager.sendCommand('wheel_calib:$_leftTrim,$_rightTrim\n');
  }

  void _updateLeftTrim(int delta) {
    setState(() {
      _leftTrim = (_leftTrim + delta).clamp(-30, 30);
    });
    _sendTrimUpdate();
  }

  void _updateRightTrim(int delta) {
    setState(() {
      _rightTrim = (_rightTrim + delta).clamp(-30, 30);
    });
    _sendTrimUpdate();
  }

  void _clearCalibration() {
    if (_isContinuousDriving) {
      setState(() {
        _isContinuousDriving = false;
      });
      widget.btManager.sendCommand('stop\n');
    }
    setState(() {
      _leftTrim = 0;
      _rightTrim = 0;
    });
    widget.btManager.sendCommand('wheel_calib_clear\n');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wheel calibration cleared from EEPROM!'),
        backgroundColor: Colors.deepOrange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _testDrive3s() {
    if (_isContinuousDriving) {
      setState(() {
        _isContinuousDriving = false;
      });
    }
    widget.btManager.sendCommand('wheel_calib:$_leftTrim,$_rightTrim\n');
    Future.delayed(const Duration(milliseconds: 50), () {
      widget.btManager.sendCommand('wheel_test\n');
    });
  }

  void _toggleContinuousDrive() {
    setState(() {
      _isContinuousDriving = !_isContinuousDriving;
    });

    if (_isContinuousDriving) {
      widget.btManager.sendCommand('wheel_calib:$_leftTrim,$_rightTrim\n');
      Future.delayed(const Duration(milliseconds: 50), () {
        widget.btManager.sendCommand('forward\n');
      });
    } else {
      widget.btManager.sendCommand('stop\n');
    }
  }

  void _saveCalibration() {
    if (_isContinuousDriving) {
      setState(() {
        _isContinuousDriving = false;
      });
      widget.btManager.sendCommand('stop\n');
    }
    widget.btManager.sendCommand('wheel_calib:$_leftTrim,$_rightTrim\n');
    Future.delayed(const Duration(milliseconds: 100), () {
      widget.btManager.sendCommand('wheel_calib_save\n');
    });
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wheel calibration saved to robot EEPROM!'),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildTrimRow(String label, int value, Function(int) onUpdate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.redAccent,
                  size: 28,
                ),
                onPressed: () => onUpdate(-1),
              ),
              Container(
                width: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  value > 0 ? '+$value' : '$value',
                  style: TextStyle(
                    color: value == 0
                        ? Colors.white
                        : (value > 0 ? Colors.greenAccent : Colors.amberAccent),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.greenAccent,
                  size: 28,
                ),
                onPressed: () => onUpdate(1),
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
      title: Row(
        children: const [
          Icon(Icons.tune, color: Colors.orangeAccent),
          SizedBox(width: 8),
          Text(
            'Wheel Calibration',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Guidance Card for Veering Left vs Right
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '💡',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Too much left: Increase Left, or Decrease Right',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Too much right: Increase Right, or Decrease Left',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildTrimRow('Left Wheel', _leftTrim, _updateLeftTrim),
            _buildTrimRow('Right Wheel', _rightTrim, _updateRightTrim),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _testDrive3s,
                  icon: const Icon(Icons.timer, size: 18),
                  label: const Text('Drive (3s)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleContinuousDrive,
                  icon: Icon(
                    _isContinuousDriving ? Icons.stop : Icons.directions_run,
                    size: 18,
                  ),
                  label: Text(
                    _isContinuousDriving ? 'Stop Drive' : 'Continuous',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isContinuousDriving
                        ? Colors.redAccent
                        : Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _clearCalibration,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_isContinuousDriving) {
              widget.btManager.sendCommand('stop\n');
            }
            Navigator.of(context).pop();
          },
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _saveCalibration,
          child: const Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
