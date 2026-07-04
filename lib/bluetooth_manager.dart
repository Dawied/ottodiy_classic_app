import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// Model for Discovered Device (Real BLE or Simulated)
class DiscoveredDevice {
  final String id;
  final String name;
  final int rssi;
  final dynamic originalDevice; // Holds BluetoothDevice if real

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.originalDevice,
  });
}

// Bluetooth State Manager
class BluetoothManager extends ChangeNotifier {
  static final BluetoothManager _instance = BluetoothManager._internal();
  factory BluetoothManager() => _instance;

  BluetoothManager._internal() {
    Future.delayed(Duration.zero, () {
      _initBluetooth();
    });
  }

  void _initBluetooth() {
    if (kIsWeb) {
      // Web Bluetooth does not support adapterState well without a user gesture,
      // and it often throws UnsupportedError. We skip it on Web.
      _adapterState = BluetoothAdapterState.unknown;
      notifyListeners();
      return;
    }
    try {
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen(
        (state) {
          _adapterState = state;
          notifyListeners();
        },
        onError: (e) {
          addLog("Bluetooth adapter state error: $e");
        },
      );
    } catch (e) {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _consoleLogs.insert(
        0,
        "[$timestamp] Failed to initialize Bluetooth adapter: $e",
      );
    }
  }

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  BluetoothAdapterState get adapterState => _adapterState;

  StreamSubscription? _adapterStateSubscription;
  StreamSubscription? _scanSubscription;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  List<DiscoveredDevice> _devices = [];
  List<DiscoveredDevice> get devices => _devices;

  DiscoveredDevice? _connectedDevice;
  DiscoveredDevice? get connectedDevice => _connectedDevice;

  String? _activeMode;
  String? get activeMode => _activeMode;

  StreamSubscription? _notifySubscription;
  Timer? _distanceClearTimer;
  double? _lastDistance;
  double? get lastDistance => _lastDistance;

  bool _isPollingUltrasound = false;
  bool get isPollingUltrasound => _isPollingUltrasound;
  Timer? _ultrasoundPollTimer;

  int _speedIndex = 2; // Default to speed index 2 (1000 ms)
  int get speedIndex => _speedIndex;

  set speedIndex(int value) {
    if (value >= 0 && value <= 5) {
      _speedIndex = value;
      notifyListeners();

      // If a mode is active, dynamically update its speed on the robot
      if (_activeMode != null) {
        sendCommand('$_activeMode$_speedIndex\n');
      }
    }
  }

  BluetoothCharacteristic? _writeCharacteristic;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final List<String> _consoleLogs = ["Otto Console initialized."];
  List<String> get consoleLogs => _consoleLogs;

  void addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _consoleLogs.insert(0, "[$timestamp] $message");
    if (_consoleLogs.length > 50) _consoleLogs.removeLast();
    notifyListeners();
  }

  Future<void> startScan() async {
    _devices.clear();
    _errorMessage = null;
    notifyListeners();
    addLog("Scanning for Otto DIY robots...");

    // Real BLE Scan
    try {
      bool isSupported = false;
      try {
        isSupported = await FlutterBluePlus.isSupported;
      } catch (e) {
        if (e is UnsupportedError || e.toString().contains('unsupported')) {
          _errorMessage = kIsWeb
              ? "Web Bluetooth requires Chrome/Edge and HTTPS."
              : "Bluetooth not natively supported on this OS/device.";
        } else {
          _errorMessage = "Bluetooth check failed: $e";
        }
        addLog("Error: $_errorMessage");
        notifyListeners();
        return;
      }

      if (!isSupported) {
        _errorMessage = "Bluetooth not supported on this device.";
        addLog("Error: $_errorMessage");
        notifyListeners();
        return;
      }

      if (!kIsWeb &&
          FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        _errorMessage = "Bluetooth is off. Please turn it on.";
        addLog("Error: $_errorMessage");
        notifyListeners();
        return;
      }

      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        _errorMessage = "Bluetooth / Location permissions denied.";
        addLog("Error: $_errorMessage");
        notifyListeners();
        return;
      }

      _isScanning = true;
      notifyListeners();

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          _devices = results
              .where(
                (r) =>
                    r.device.platformName.isNotEmpty ||
                    r.device.remoteId.str.isNotEmpty,
              )
              .map((r) {
                final name = r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : r.device.remoteId.str;
                return DiscoveredDevice(
                  id: r.device.remoteId.str,
                  name: name,
                  rssi: r.rssi,
                  originalDevice: r.device,
                );
              })
              .toList();
          notifyListeners();
        },
        onError: (e) {
          _errorMessage = "Scan stream error: $e";
          _isScanning = false;
          addLog("Error: $_errorMessage");
          notifyListeners();
        },
      );

      List<Guid> scanServices = [];
      if (kIsWeb) {
        // Web Bluetooth requires services to be specified ahead of time
        // to be allowed access during discoverServices.
        scanServices = [
          Guid("0000ffe0-0000-1000-8000-00805f9b34fb"), // HM-10 / AT-09
          Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e"), // Nordic UART
        ];
      }

      await FlutterBluePlus.startScan(
        withServices: scanServices,
        timeout: const Duration(seconds: 8),
      );

      if (kIsWeb) {
        // Wait up to 1 second for the device stream to populate after browser picker closes
        for (int i = 0; i < 10; i++) {
          if (_devices.isNotEmpty) break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      _isScanning = false;
      addLog("BLE scan finished. Found ${_devices.length} devices.");

      // Auto-connect on web since the browser picker already handled selection
      if (kIsWeb && _devices.isNotEmpty) {
        addLog("Web Bluetooth: Auto-connecting to selected device...");
        connect(_devices.first);
      }

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

  Future<void> connect(DiscoveredDevice device) async {
    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();
    addLog("Connecting to ${device.name}...");

    // Real BLE Connection
    try {
      final bluetoothDevice = device.originalDevice as BluetoothDevice;

      // Listen to connection state updates
      bluetoothDevice.connectionState.listen(
        (state) {
          if (state == BluetoothConnectionState.disconnected) {
            if (_connectedDevice?.id == device.id) {
              _connectedDevice = null;
              _activeMode = null;
              _notifySubscription?.cancel();
              _notifySubscription = null;
              _distanceClearTimer?.cancel();
              _distanceClearTimer = null;
              _lastDistance = null;
              _isPollingUltrasound = false;
              _ultrasoundPollTimer?.cancel();
              _ultrasoundPollTimer = null;
              addLog("Disconnected from ${device.name}.");
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
      _connectedDevice = device;
      addLog("Connected to BLE device: ${device.name}");

      // Discover BLE Services (standard for BLE communication)
      addLog("Discovering services...");
      List<BluetoothService> services = await bluetoothDevice
          .discoverServices();
      addLog("Services discovered successfully.");

      // Find write characteristic
      _writeCharacteristic = null;
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            String uuid = characteristic.uuid.str.toLowerCase();
            if (uuid.contains("ffe1") || uuid.contains("6e400002")) {
              _writeCharacteristic = characteristic;
              break; // Found preferred serial characteristic
            } else {
              _writeCharacteristic ??= characteristic;
            }
          }
        }
        if (_writeCharacteristic != null &&
            (_writeCharacteristic!.uuid.str.toLowerCase().contains("ffe1") ||
                _writeCharacteristic!.uuid.str.toLowerCase().contains(
                  "6e400002",
                ))) {
          break;
        }
      }

      if (_writeCharacteristic != null) {
        addLog("Ready to send commands.");
      } else {
        addLog("Warning: No writable characteristic found.");
      }

      // Find notify/read characteristic and subscribe
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
                notifyCharacteristic.uuid.str.toLowerCase().contains(
                  "6e400003",
                ))) {
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
            },
            onError: (e) {
              addLog("Notification error: $e");
            },
          );
        } catch (e) {
          addLog("Failed to subscribe to notifications: $e");
        }
      } else {
        addLog("Warning: No notify characteristic found.");
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
      final bluetoothDevice =
          _connectedDevice!.originalDevice as BluetoothDevice;
      await bluetoothDevice.disconnect();
    } catch (e) {
      addLog("Disconnect error: $e");
    } finally {
      _connectedDevice = null;
      _activeMode = null;
      _notifySubscription?.cancel();
      _notifySubscription = null;
      _distanceClearTimer?.cancel();
      _distanceClearTimer = null;
      _lastDistance = null;
      _isPollingUltrasound = false;
      _ultrasoundPollTimer?.cancel();
      _ultrasoundPollTimer = null;
      notifyListeners();
    }
  }

  void sendCommand(String command) {
    if (_connectedDevice == null) {
      addLog("Cannot send command: No device connected.");
      return;
    }

    if (_writeCharacteristic == null) {
      addLog("Error: No writable characteristic to send command.");
      return;
    }

    addLog("Sent Command: '${command.trim()}'");

    final cmdClean = command.trim().toLowerCase();
    if (!cmdClean.startsWith('ultrasound')) {
      if (_isPollingUltrasound) {
        _isPollingUltrasound = false;
        _ultrasoundPollTimer?.cancel();
        _ultrasoundPollTimer = null;
      }
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

    try {
      _writeCharacteristic!.write(
        command.codeUnits,
        withoutResponse: _writeCharacteristic!.properties.writeWithoutResponse,
      );
    } catch (e) {
      addLog("Write error: $e");
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
    _ultrasoundPollTimer = Timer.periodic(const Duration(milliseconds: 1000), (
      timer,
    ) {
      if (_connectedDevice == null) {
        stopUltrasoundPolling();
        return;
      }
      try {
        _writeCharacteristic?.write(
          "ultrasound2\n".codeUnits,
          withoutResponse:
              _writeCharacteristic!.properties.writeWithoutResponse,
        );
        addLog("Polling ultrasound...");
      } catch (e) {
        addLog("Polling error: $e");
        stopUltrasoundPolling();
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

  Future<bool> _requestPermissions() async {
    if (kIsWeb) return true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();
      final locationStatus = await Permission.location.request();
      return scanStatus.isGranted &&
          connectStatus.isGranted &&
          locationStatus.isGranted;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final bluetoothStatus = await Permission.bluetooth.request();
      return bluetoothStatus.isGranted;
    }
    return true;
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _distanceClearTimer?.cancel();
    _ultrasoundPollTimer?.cancel();
    super.dispose();
  }
}
