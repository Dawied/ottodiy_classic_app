import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Model for Discovered Device
class DiscoveredDevice {
  final String id;
  final String name;
  final int rssi;
  final dynamic originalDevice;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.originalDevice,
  });
}

/// Web Bluetooth State Manager for Otto DIY Robot
class BluetoothManager extends ChangeNotifier {
  static final BluetoothManager _instance = BluetoothManager._internal();
  factory BluetoothManager() => _instance;

  BluetoothManager._internal() {
    _loadPreferences();
  }

  StreamSubscription? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  List<DiscoveredDevice> _devices = [];
  List<DiscoveredDevice> get devices => _devices;

  DiscoveredDevice? _connectedDevice;
  DiscoveredDevice? get connectedDevice => _connectedDevice;

  String? _activeMode;
  String? get activeMode => _activeMode;

  BluetoothCharacteristic? _writeCharacteristic;
  StreamSubscription? _notifySubscription;

  String? _pendingCommand;
  bool _isSending = false;

  Timer? _distanceClearTimer;
  double? _lastDistance;
  double? get lastDistance => _lastDistance;

  bool _isPollingUltrasound = false;
  bool get isPollingUltrasound => _isPollingUltrasound;
  Timer? _ultrasoundPollTimer;

  Timer? _lineSensorClearTimer;
  String? _lastLineSensorState;
  String? get lastLineSensorState => _lastLineSensorState;

  bool _isPollingLineSensor = false;
  bool get isPollingLineSensor => _isPollingLineSensor;
  Timer? _lineSensorPollTimer;

  static const Map<int, String> availableSounds = {
    0: 'No Sound',
    1: 'Connection',
    2: 'Disconnection',
    3: 'Button Pushed',
    4: 'Mode 1',
    5: 'Mode 2',
    6: 'Surprise',
    7: 'OhOoh',
    8: 'OhOoh 2',
    9: 'Cuddly',
    10: 'Sleeping',
    12: 'Happy',
    13: 'Super Happy',
    14: 'Sad',
    15: 'Confused',
    17: 'Fart 1',
    18: 'Fart 2',
    19: 'Fart 3',
  };

  int _avoidanceDistance = 15;
  int get avoidanceDistance => _avoidanceDistance;

  int _avoidanceSound = 0; // Default to 0 (No Sound)
  int get avoidanceSound => _avoidanceSound;

  int _speedIndex = 2; // Default to speed index 2
  int get speedIndex => _speedIndex;

  set speedIndex(int value) {
    if (value >= 0 && value <= 5) {
      _speedIndex = value;
      notifyListeners();

      if (_activeMode != null) {
        sendCommand('$_activeMode$_speedIndex\n');
      }
    }
  }

  String get lineSensorLabel {
    if (_lastLineSensorState == null) return 'Line Sensors';
    switch (_lastLineSensorState) {
      case '0,0':
        return 'Sensors: L:⚪ R:⚪ (Forward)';
      case '1,0':
        return 'Sensors: L:⚫ R:⚪ (Turn Left)';
      case '0,1':
        return 'Sensors: L:⚪ R:⚫ (Turn Right)';
      case '1,1':
        return 'Sensors: L:⚫ R:⚫ (Stop)';
      default:
        return 'Sensors: $_lastLineSensorState';
    }
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final List<String> _consoleLogs = ["Web Bluetooth Manager initialized."];
  List<String> get consoleLogs => _consoleLogs;

  void addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _consoleLogs.insert(0, "[$timestamp] $message");
    if (_consoleLogs.length > 50) _consoleLogs.removeLast();
    notifyListeners();
  }

  void _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _avoidanceDistance = prefs.getInt('avoidance_distance') ?? 15;
      _avoidanceSound = prefs.getInt('avoidance_sound') ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  void setAvoidanceDistance(int dist) async {
    if (dist < 5) dist = 5;
    if (dist > 40) dist = 40;
    if (_avoidanceDistance != dist) {
      _avoidanceDistance = dist;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('avoidance_distance', dist);
      } catch (_) {}

      if (_connectedDevice != null) {
        sendCommand('avoidance_dist$dist\n');
      }
    }
  }

  void setAvoidanceSound(int soundId) async {
    if (_avoidanceSound != soundId) {
      _avoidanceSound = soundId;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('avoidance_sound', soundId);
      } catch (_) {}

      if (_connectedDevice != null) {
        sendCommand('avoidance_sound$soundId\n');
      }
    }
  }

  /// Triggers Chrome's native Web Bluetooth selection picker
  Future<void> startScan() async {
    _devices.clear();
    _errorMessage = null;
    _isScanning = true;
    notifyListeners();
    addLog("Opening Web Bluetooth selection picker...");

    try {
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          final validResults = results
              .where(
                (r) =>
                    r.device.platformName.isNotEmpty ||
                    r.device.remoteId.str.isNotEmpty,
              )
              .toList();

          if (validResults.isNotEmpty) {
            _devices = validResults.map((r) {
              final name = r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : r.device.remoteId.str;
              return DiscoveredDevice(
                id: r.device.remoteId.str,
                name: name,
                rssi: r.rssi,
                originalDevice: r.device,
              );
            }).toList();

            notifyListeners();

            if (_connectedDevice == null && !_isConnecting) {
              addLog("Device selected in browser. Connecting immediately...");
              FlutterBluePlus.stopScan();
              connect(_devices.first);
            }
          }
        },
        onError: (e) {
          _errorMessage = "Scan error: $e";
          _isScanning = false;
          addLog("Error: $_errorMessage");
          notifyListeners();
        },
      );

      List<Guid> scanServices = [
        Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e"), // Nordic UART (Otto BLE / ESP32)
        Guid("0000ffe0-0000-1000-8000-00805f9b34fb"), // HM-10 / AT-09 / MLT-BT05
        Guid("0000fff0-0000-1000-8000-00805f9b34fb"), // JDY Serial
        Guid("0000ffe1-0000-1000-8000-00805f9b34fb"),
        Guid("00001101-0000-1000-8000-00805f9b34fb"),
      ];

      await FlutterBluePlus.startScan(
        withServices: scanServices,
        timeout: const Duration(seconds: 15),
      );

      _isScanning = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = "Scan failed: $e";
      _isScanning = false;
      addLog("Error: $_errorMessage");
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  Future<void> _cleanupConnection({bool cancelSubscription = true}) async {
    _connectedDevice = null;
    _writeCharacteristic = null;
    _pendingCommand = null;
    _activeMode = null;

    await _notifySubscription?.cancel();
    _notifySubscription = null;

    _distanceClearTimer?.cancel();
    _distanceClearTimer = null;
    _lastDistance = null;

    _isPollingUltrasound = false;
    _ultrasoundPollTimer?.cancel();
    _ultrasoundPollTimer = null;

    _lineSensorClearTimer?.cancel();
    _lineSensorClearTimer = null;
    _lastLineSensorState = null;

    _isPollingLineSensor = false;
    _lineSensorPollTimer?.cancel();
    _lineSensorPollTimer = null;

    if (cancelSubscription) {
      await _connectionSubscription?.cancel();
    }
    _connectionSubscription = null;
  }

  /// Establishes GATT connection and discovers characteristics
  Future<void> connect(DiscoveredDevice device) async {
    _isConnecting = true;
    _errorMessage = null;
    await _connectionSubscription?.cancel();
    notifyListeners();
    addLog("Connecting to Web Bluetooth device: ${device.name}...");

    try {
      final bluetoothDevice = device.originalDevice as BluetoothDevice;

      _connectionSubscription = bluetoothDevice.connectionState.listen(
        (state) async {
          if (state == BluetoothConnectionState.disconnected) {
            if (_connectedDevice?.id == device.id) {
              addLog("Disconnected from ${device.name}.");
              await _cleanupConnection(cancelSubscription: false);
              notifyListeners();
            }
          }
        },
        onError: (e) {
          addLog("Connection state error: $e");
        },
      );

      await bluetoothDevice.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 10),
      );
      addLog("GATT connection established with ${device.name}.");

      List<BluetoothService> services = await bluetoothDevice.discoverServices();
      addLog("GATT services discovered.");

      _writeCharacteristic = null;
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            String uuid = characteristic.uuid.str.toLowerCase();
            if (uuid.contains("ffe1") || uuid.contains("6e400002")) {
              _writeCharacteristic = characteristic;
              break;
            } else {
              _writeCharacteristic ??= characteristic;
            }
          }
        }
        if (_writeCharacteristic != null &&
            (_writeCharacteristic!.uuid.str.toLowerCase().contains("ffe1") ||
                _writeCharacteristic!.uuid.str.toLowerCase().contains("6e400002"))) {
          break;
        }
      }

      // Find notify characteristic and subscribe
      BluetoothCharacteristic? notifyCharacteristic;
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            String uuid = characteristic.uuid.str.toLowerCase();
            if (uuid.contains("ffe1") || uuid.contains("6e400003")) {
              notifyCharacteristic = characteristic;
              break;
            } else {
              notifyCharacteristic ??= characteristic;
            }
          }
        }
        if (notifyCharacteristic != null &&
            (notifyCharacteristic.uuid.str.toLowerCase().contains("ffe1") ||
                notifyCharacteristic.uuid.str.toLowerCase().contains("6e400003"))) {
          break;
        }
      }

      if (notifyCharacteristic != null) {
        addLog("Subscribing to notifications...");
        try {
          await notifyCharacteristic.setNotifyValue(true);
          _notifySubscription?.cancel();
          _notifySubscription = notifyCharacteristic.onValueReceived.listen(
            (value) {
              final rawData = String.fromCharCodes(value).trim();
              if (rawData.startsWith("LINE:")) {
                _lastLineSensorState = rawData.substring(5).trim();
                addLog("Line status received: $_lastLineSensorState");
                notifyListeners();

                _lineSensorClearTimer?.cancel();
                if (!_isPollingLineSensor) {
                  _lineSensorClearTimer = Timer(const Duration(seconds: 5), () {
                    _lastLineSensorState = null;
                    notifyListeners();
                  });
                }
              } else {
                final double? dist = double.tryParse(rawData);
                if (dist != null) {
                  _lastDistance = dist;
                  addLog("Distance received: ${dist.toStringAsFixed(1)} cm");
                  notifyListeners();

                  _distanceClearTimer?.cancel();
                  if (!_isPollingUltrasound) {
                    _distanceClearTimer = Timer(const Duration(seconds: 5), () {
                      _lastDistance = null;
                      notifyListeners();
                    });
                  }
                }
              }
            },
            onError: (e) {
              addLog("Notification error: $e");
            },
          );
        } catch (e) {
          addLog("Failed to subscribe to notifications: $e");
        }
      }

      if (_writeCharacteristic != null) {
        _connectedDevice = device;
        addLog("Write characteristic ready. Otto connected.");

        // Flush any buffered command
        if (_pendingCommand != null) {
          final cmdToSend = _pendingCommand!;
          _pendingCommand = null;
          addLog("Flushing buffered initial command: '${cmdToSend.trim()}'");
          await sendCommand(cmdToSend);
        }
      } else {
        addLog("Warning: No writable characteristic found.");
      }
    } catch (e) {
      _errorMessage = "Connection failed: $e";
      addLog("Error: $_errorMessage");
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice == null) return;
    final name = _connectedDevice!.name;
    addLog("Disconnecting from $name...");

    try {
      final bluetoothDevice = _connectedDevice!.originalDevice as BluetoothDevice;
      await bluetoothDevice.disconnect();
    } catch (e) {
      addLog("Disconnect error: $e");
    } finally {
      await _cleanupConnection();
      notifyListeners();
    }
  }

  /// Sends command over BLE write characteristic using Last-In-Wins single-slot buffering
  Future<void> sendCommand(String command) async {
    _pendingCommand = command;

    final cmdClean = command.trim().toLowerCase();
    if (!cmdClean.startsWith('ultrasound') && !cmdClean.startsWith('linesensor')) {
      if (_isPollingUltrasound) stopUltrasoundPolling();
      if (_isPollingLineSensor) stopLineSensorPolling();
    }

    if (cmdClean.startsWith('avoidance')) {
      _activeMode = 'avoidance';
    } else if (cmdClean.startsWith('line_follower')) {
      _activeMode = 'line_follower';
    } else if (cmdClean.startsWith('force')) {
      _activeMode = 'force';
    } else if (cmdClean.startsWith('stop') ||
        cmdClean.startsWith('forward') ||
        cmdClean.startsWith('backward') ||
        cmdClean.startsWith('left') ||
        cmdClean.startsWith('right') ||
        cmdClean.startsWith('happy') ||
        cmdClean.startsWith('victory') ||
        cmdClean.startsWith('sad') ||
        cmdClean.startsWith('sleeping') ||
        cmdClean.startsWith('confused') ||
        cmdClean.startsWith('fail') ||
        cmdClean.startsWith('fart') ||
        cmdClean.startsWith('love') ||
        cmdClean.startsWith('fretful') ||
        cmdClean.startsWith('magic') ||
        cmdClean.startsWith('sing') ||
        cmdClean.startsWith('walk_test') ||
        cmdClean.startsWith('ultrasound')) {
      _activeMode = null;
    }

    notifyListeners();

    if (_connectedDevice == null || _writeCharacteristic == null) return;
    if (_isSending) return;

    _isSending = true;

    try {
      while (_pendingCommand != null &&
          _connectedDevice != null &&
          _writeCharacteristic != null) {
        final cmdToSend = _pendingCommand!;
        _pendingCommand = null;

        addLog("Sent Command: '${cmdToSend.trim()}'");

        await _writeCharacteristic!.write(
          cmdToSend.codeUnits,
          withoutResponse: _writeCharacteristic!.properties.writeWithoutResponse,
        );

        await Future.delayed(const Duration(milliseconds: 30));
      }
    } catch (e) {
      addLog("BLE write failed: $e");
      await disconnect();
    } finally {
      _isSending = false;
    }
  }

  void toggleUltrasoundPolling() {
    if (_isPollingUltrasound) {
      stopUltrasoundPolling();
    } else {
      startUltrasoundPolling();
    }
  }

  void startUltrasoundPolling() {
    if (_connectedDevice == null) return;
    sendCommand('stop2\n');
    _isPollingUltrasound = true;
    _lastDistance = null;
    notifyListeners();

    _ultrasoundPollTimer?.cancel();
    _ultrasoundPollTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (_connectedDevice == null) {
        stopUltrasoundPolling();
        return;
      }

      try {
        await _writeCharacteristic!.write(
          "ultrasound2\n".codeUnits,
          withoutResponse:
              _writeCharacteristic!.properties.writeWithoutResponse,
        );
        addLog("Polling ultrasound...");
      } catch (e) {
        addLog("Ultrasound polling failed: $e");
        await disconnect();
      }
    });
  }

  void stopUltrasoundPolling() {
    if (!_isPollingUltrasound) return;
    _isPollingUltrasound = false;
    _ultrasoundPollTimer?.cancel();
    _ultrasoundPollTimer = null;
    _lastDistance = null;
    notifyListeners();
  }

  void toggleLineSensorPolling() {
    if (_isPollingLineSensor) {
      stopLineSensorPolling();
    } else {
      startLineSensorPolling();
    }
  }

  void startLineSensorPolling() {
    if (_connectedDevice == null) return;
    sendCommand('stop2\n');
    _isPollingLineSensor = true;
    _lastLineSensorState = null;
    notifyListeners();

    _lineSensorPollTimer?.cancel();
    _lineSensorPollTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (_connectedDevice == null) {
        stopLineSensorPolling();
        return;
      }

      try {
        await _writeCharacteristic!.write(
          "linesensor2\n".codeUnits,
          withoutResponse:
              _writeCharacteristic!.properties.writeWithoutResponse,
        );
        addLog("Polling line sensors...");
      } catch (e) {
        addLog("Line sensor polling failed: $e");
        await disconnect();
      }
    });
  }

  void stopLineSensorPolling() {
    if (!_isPollingLineSensor) return;
    _isPollingLineSensor = false;
    _lineSensorPollTimer?.cancel();
    _lineSensorPollTimer = null;
    _lastLineSensorState = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _distanceClearTimer?.cancel();
    _ultrasoundPollTimer?.cancel();
    _lineSensorClearTimer?.cancel();
    _lineSensorPollTimer?.cancel();
    super.dispose();
  }
}
