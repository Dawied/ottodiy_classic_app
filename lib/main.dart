import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        _adapterState = state;
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      _adapterState = BluetoothAdapterState.on;
    }
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget screen = _adapterState == BluetoothAdapterState.on || kIsWeb
        ? const HomeScreen()
        : BluetoothOffScreen(adapterState: _adapterState);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          elevation: 0,
        ),
      ),
      home: screen,
      navigatorObservers: [BluetoothAdapterStateObserver()],
    );
  }
}

class BluetoothAdapterStateObserver extends NavigatorObserver {
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == '/DeviceScreen') {
      _adapterStateSubscription ??= FlutterBluePlus.adapterState.listen((
        state,
      ) {
        if (state != BluetoothAdapterState.on) {
          navigator?.pop();
        }
      });
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({super.key, this.adapterState});

  final BluetoothAdapterState? adapterState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${adapterState?.toString().split(".").last}.',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

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

// Main Screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BluetoothManager _btManager = BluetoothManager();
  bool _isConsoleVisible = false;

  String _getSpeedLabel(int index) {
    switch (index) {
      case 0:
        return 'Very Slow (3.0s)';
      case 1:
        return 'Slow (2.0s)';
      case 2:
        return 'Normal (1.0s)';
      case 3:
        return 'Fast (0.75s)';
      case 4:
        return 'Very Fast (0.5s)';
      case 5:
        return 'Turbo (0.25s)';
      default:
        return 'Normal';
    }
  }

  void _showConnectionModal() {
    if (!_btManager.isScanning && _btManager.connectedDevice == null) {
      _btManager.startScan();
    }

    bool isClosing = false;
    void connectionListener() async {
      if (!isClosing && _btManager.connectedDevice != null && mounted) {
        isClosing = true;
        _btManager.removeListener(connectionListener);
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    }

    _btManager.addListener(connectionListener);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListenableBuilder(
          listenable: _btManager,
          builder: (context, _) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Otto DIY Connection',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.grey, thickness: 0.5),
                  const SizedBox(height: 10),

                  // Scan status
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _btManager.isScanning
                          ? Colors.redAccent.withValues(alpha: 0.2)
                          : const Color(0xFF00E5FF),
                      foregroundColor: _btManager.isScanning
                          ? Colors.redAccent
                          : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _btManager.isScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.redAccent,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      _btManager.isScanning
                          ? 'Scanning... Stop'
                          : 'Scan for Otto Robots',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      if (_btManager.isScanning) {
                        _btManager.stopScan();
                      } else {
                        _btManager.startScan();
                      }
                    },
                  ),
                  const SizedBox(height: 15),

                  if (_btManager.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        _btManager.errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],

                  // Connection progress
                  if (_btManager.isConnecting) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: Color(0xFF00E5FF)),
                            SizedBox(height: 12),
                            Text(
                              'Connecting to Otto DIY...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Discovered devices list
                    const Text(
                      'Discovered Devices',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: _btManager.devices.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 30),
                                child: Text(
                                  'No devices found yet. Tap Scan.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _btManager.devices.length,
                              itemBuilder: (context, index) {
                                final dev = _btManager.devices[index];
                                final isConnected =
                                    _btManager.connectedDevice?.id == dev.id;

                                return Card(
                                  color: const Color(0xFF1F2937),
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    onTap: () {
                                      if (isConnected) {
                                        _btManager.disconnect();
                                      } else {
                                        _btManager.connect(dev);
                                      }
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: isConnected
                                          ? const Color(
                                              0xFF00E5FF,
                                            ).withValues(alpha: 0.2)
                                          : Colors.grey.withValues(alpha: 0.1),
                                      child: Icon(
                                        Icons.smart_toy,
                                        color: isConnected
                                            ? const Color(0xFF00E5FF)
                                            : Colors.white70,
                                      ),
                                    ),
                                    title: Text(
                                      dev.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'ID: ${dev.id} | RSSI: ${dev.rssi} dBm',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isConnected
                                            ? Colors.redAccent
                                            : const Color(0xFF00E5FF),
                                        foregroundColor: isConnected
                                            ? Colors.white
                                            : Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        if (isConnected) {
                                          _btManager.disconnect();
                                        } else {
                                          _btManager.connect(dev);
                                        }
                                      },
                                      child: Text(
                                        isConnected ? 'Disconnect' : 'Connect',
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _btManager.removeListener(connectionListener);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _btManager,
      builder: (context, _) {
        final isConnected = _btManager.connectedDevice != null;

        return Scaffold(
          appBar: AppBar(
            leadingWidth: 140,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: TextButton.icon(
                icon: Icon(
                  Icons.smart_toy,
                  color: isConnected ? const Color(0xFF00E5FF) : Colors.grey,
                  size: 20,
                ),
                label: Text(
                  isConnected ? "Disconnect" : "Connect",
                  style: TextStyle(
                    color: isConnected ? const Color(0xFF00E5FF) : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onPressed: isConnected
                    ? () => _btManager.disconnect()
                    : _showConnectionModal,
              ),
            ),
            title: const Text(
              'OTTO DIY',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.terminal,
                  color: _isConsoleVisible
                      ? const Color(0xFF00E5FF)
                      : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _isConsoleVisible = !_isConsoleVisible;
                  });
                },
              ),
              const SizedBox(width: 8),
            ],
            centerTitle: true,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top robot status panel
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isConnected
                              ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
                              : Colors.white10,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Beautiful robot pulse visualization
                          _RobotVisualizer(
                            isConnected: isConnected,
                            onTap: isConnected
                                ? () => _btManager.disconnect()
                                : _showConnectionModal,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isConnected
                                ? 'OTTO CONNECTED'
                                : 'OTTO DISCONNECTED',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isConnected
                                  ? const Color(0xFF00E5FF)
                                  : Colors.grey,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isConnected
                                ? 'Device: ${_btManager.connectedDevice!.name}'
                                : 'Connect via Bluetooth to start controlling',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Controls Grid
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Opacity(
                          opacity: isConnected ? 1.0 : 0.4,
                          child: AbsorbPointer(
                            absorbing: !isConnected,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'WALK',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // Joystick D-Pad Layout
                                  Align(
                                    alignment: Alignment.center,
                                    child: Column(
                                      children: [
                                        // Up
                                        _JoystickButton(
                                          icon: Icons.keyboard_arrow_up,
                                          color: const Color(0xFF00E5FF),
                                          onPressed: () => _btManager.sendCommand(
                                            'forward${_btManager.speedIndex}\n',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Middle Row
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _JoystickButton(
                                              icon: Icons.keyboard_arrow_left,
                                              color: const Color(0xFF00E5FF),
                                              onPressed: () =>
                                                  _btManager.sendCommand(
                                                    'left${_btManager.speedIndex}\n',
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                            _JoystickButton(
                                              icon: Icons.stop_circle_outlined,
                                              color: Colors.redAccent,
                                              isCenter: true,
                                              onPressed: () =>
                                                  _btManager.sendCommand(
                                                    'stop${_btManager.speedIndex}\n',
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                            _JoystickButton(
                                              icon: Icons.keyboard_arrow_right,
                                              color: const Color(0xFF00E5FF),
                                              onPressed: () =>
                                                  _btManager.sendCommand(
                                                    'right${_btManager.speedIndex}\n',
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Down
                                        _JoystickButton(
                                          icon: Icons.keyboard_arrow_down,
                                          color: const Color(0xFF00E5FF),
                                          onPressed: () => _btManager.sendCommand(
                                            'backward${_btManager.speedIndex}\n',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Speed Slider
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.speed,
                                        color: Colors.grey,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'SPEED',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _getSpeedLabel(_btManager.speedIndex),
                                        style: const TextStyle(
                                          color: Color(0xFF00E5FF),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Slider(
                                    value: _btManager.speedIndex.toDouble(),
                                    min: 0,
                                    max: 5,
                                    divisions: 5,
                                    activeColor: const Color(0xFF00E5FF),
                                    inactiveColor: Colors.white10,
                                    onChanged: (value) {
                                      _btManager.speedIndex = value.round();
                                    },
                                  ),
                                  const SizedBox(height: 24),
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
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _SmallButton(
                                        'Happy',
                                        Icons.mood,
                                        Colors.amber,
                                        () =>
                                            _btManager.sendCommand('happy2\n'),
                                      ),
                                      _SmallButton(
                                        'Victory',
                                        Icons.emoji_events,
                                        Colors.amber,
                                        () => _btManager.sendCommand(
                                          'victory2\n',
                                        ),
                                      ),
                                      _SmallButton(
                                        'Sad',
                                        Icons.mood_bad,
                                        Colors.amber,
                                        () => _btManager.sendCommand('sad2\n'),
                                      ),
                                      _SmallButton(
                                        'Sleep',
                                        Icons.hotel,
                                        Colors.amber,
                                        () => _btManager.sendCommand(
                                          'sleeping2\n',
                                        ),
                                      ),
                                      _SmallButton(
                                        'Confused',
                                        Icons.question_mark,
                                        Colors.amber,
                                        () => _btManager.sendCommand(
                                          'confused2\n',
                                        ),
                                      ),
                                      _SmallButton(
                                        'Fail',
                                        Icons.error_outline,
                                        Colors.amber,
                                        () => _btManager.sendCommand('fail2\n'),
                                      ),
                                      _SmallButton(
                                        'Fart',
                                        Icons.air,
                                        Colors.amber,
                                        () => _btManager.sendCommand('fart2\n'),
                                      ),
                                      _SmallButton(
                                        'Love',
                                        Icons.favorite,
                                        Colors.amber,
                                        () => _btManager.sendCommand('love2\n'),
                                      ),
                                      _SmallButton(
                                        'Fretful',
                                        Icons.warning_amber_rounded,
                                        Colors.amber,
                                        () => _btManager.sendCommand(
                                          'fretful2\n',
                                        ),
                                      ),
                                      _SmallButton(
                                        'Magic',
                                        Icons.auto_awesome,
                                        Colors.amber,
                                        () =>
                                            _btManager.sendCommand('magic2\n'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'SING',
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
                                      _SmallButton(
                                        'Connection',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 0\n'),
                                      ),
                                      _SmallButton(
                                        'Disconnection',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 1\n'),
                                      ),
                                      _SmallButton(
                                        'Button Pushed',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 2\n'),
                                      ),
                                      _SmallButton(
                                        'Mode 1',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 3\n'),
                                      ),
                                      _SmallButton(
                                        'Mode 2',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 4\n'),
                                      ),
                                      _SmallButton(
                                        'Mode 3',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 5\n'),
                                      ),
                                      _SmallButton(
                                        'Surprise',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 6\n'),
                                      ),
                                      _SmallButton(
                                        'OhOoh',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 7\n'),
                                      ),
                                      _SmallButton(
                                        'OhOoh 2',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 8\n'),
                                      ),
                                      _SmallButton(
                                        'Cuddly',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 9\n'),
                                      ),
                                      _SmallButton(
                                        'Sleeping',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 10\n'),
                                      ),
                                      _SmallButton(
                                        'Happy',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 11\n'),
                                      ),
                                      _SmallButton(
                                        'Super Happy',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 12\n'),
                                      ),
                                      _SmallButton(
                                        'Happy Short',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 13\n'),
                                      ),
                                      _SmallButton(
                                        'Sad',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 14\n'),
                                      ),
                                      _SmallButton(
                                        'Confused',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 15\n'),
                                      ),
                                      _SmallButton(
                                        'Fart 1',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 16\n'),
                                      ),
                                      _SmallButton(
                                        'Fart 2',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 17\n'),
                                      ),
                                      _SmallButton(
                                        'Fart 3',
                                        Icons.music_note,
                                        const Color(0xFFFFB300),
                                        () =>
                                            _btManager.sendCommand('sing 18\n'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'MODES',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _ControlButton(
                                              icon: Icons.remove_red_eye,
                                              label: 'AVOIDANCE',
                                              color: Colors.lightGreenAccent,
                                              isActive:
                                                  _btManager.activeMode ==
                                                  'avoidance',
                                              onPressed: () {
                                                if (_btManager.activeMode ==
                                                    'avoidance') {
                                                  _btManager.sendCommand(
                                                    'stop${_btManager.speedIndex}\n',
                                                  );
                                                } else {
                                                  _btManager.sendCommand(
                                                    'avoidance${_btManager.speedIndex}\n',
                                                  );
                                                }
                                              },
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Otto starts walking and avoids obstacles',
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 11,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _ControlButton(
                                              icon: Icons.sports_martial_arts,
                                              label: 'USE FORCE',
                                              color: Colors.lightBlueAccent,
                                              isActive:
                                                  _btManager.activeMode ==
                                                  'force',
                                              onPressed: () {
                                                if (_btManager.activeMode ==
                                                    'force') {
                                                  _btManager.sendCommand(
                                                    'stop${_btManager.speedIndex}\n',
                                                  );
                                                } else {
                                                  _btManager.sendCommand(
                                                    'force${_btManager.speedIndex}\n',
                                                  );
                                                }
                                              },
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Move your hand in front of Otto to have it react to it',
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 11,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
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
                                      _SmallButton(
                                        _btManager.lastDistance != null
                                            ? 'Distance: ${_btManager.lastDistance!.toStringAsFixed(0)} cm'
                                            : 'Distance',
                                        Icons.sensors,
                                        Colors.tealAccent,
                                        () => _btManager
                                            .toggleUltrasoundPolling(),
                                        isActive:
                                            _btManager.isPollingUltrasound,
                                      ),
                                      _SmallButton(
                                        'Walk Test',
                                        Icons.directions_walk,
                                        Colors.pinkAccent,
                                        () => _btManager.sendCommand(
                                          'walk_test2\n',
                                        ),
                                      ),
                                      _SmallButton(
                                        'Calibrate',
                                        Icons.build,
                                        Colors.orangeAccent,
                                        () {
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) =>
                                                _CalibrationDialog(
                                                  btManager: _btManager,
                                                ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Console / Serial Logs
                    if (_isConsoleVisible) ...[
                      const SizedBox(height: 16),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF020617),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'CONSOLE LOGS',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.grey,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isConsoleVisible = false;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _btManager.consoleLogs.length,
                                  itemBuilder: (context, index) {
                                    final log = _btManager.consoleLogs[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2.0,
                                      ),
                                      child: Text(
                                        log,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: Color(
                                            0xFF34D399,
                                          ), // terminal green
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Controller button widget with micro-animations on tap/hover
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverScale(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        height: 50,
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? color : const Color(0xFF1E293B),
            foregroundColor: isActive ? Colors.black : color,
            side: BorderSide(
              color: isActive ? color : color.withValues(alpha: 0.5),
              width: isActive ? 2 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: isActive ? 6 : 2,
            shadowColor: isActive ? color : Colors.black,
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 22),
          label: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 13,
              color: isActive ? Colors.black : color,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isActive;

  const _SmallButton(
    this.label,
    this.icon,
    this.color,
    this.onPressed, {
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverScale(
      child: ActionChip(
        backgroundColor: isActive ? color : const Color(0xFF1E293B),
        side: BorderSide(
          color: isActive ? color : color.withValues(alpha: 0.5),
        ),
        avatar: Icon(icon, color: isActive ? Colors.black : color, size: 16),
        label: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : color,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _JoystickButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isCenter;

  const _JoystickButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverScale(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(
            color: isCenter
                ? color.withValues(alpha: 0.1)
                : const Color(0xFF1E293B),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.5),
              width: isCenter ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, size: 36, color: color),
        ),
      ),
    );
  }
}

// Robot Visualizer that glows when connected
class _RobotVisualizer extends StatelessWidget {
  final bool isConnected;
  final VoidCallback? onTap;

  const _RobotVisualizer({required this.isConnected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final glowColor = isConnected
        ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
        : Colors.transparent;

    return _HoverScale(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: isConnected ? 25 : 0,
                spreadRadius: isConnected ? 5 : 0,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 40,
            backgroundColor: isConnected
                ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                : Colors.white10,
            child: Icon(
              isConnected ? Icons.smart_toy : Icons.smart_toy_outlined,
              size: 44,
              color: isConnected ? const Color(0xFF00E5FF) : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverScale extends StatefulWidget {
  final Widget child;
  const _HoverScale({required this.child});

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _CalibrationDialog extends StatefulWidget {
  final BluetoothManager btManager;

  const _CalibrationDialog({required this.btManager});

  @override
  State<_CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends State<_CalibrationDialog> {
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
