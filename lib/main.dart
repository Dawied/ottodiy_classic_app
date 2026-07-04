import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'utils/download_helper.dart';
import 'bluetooth_manager.dart';

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
      title: 'Otto DIY Classic',
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

// Main Screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BluetoothManager _btManager = BluetoothManager();
  bool _isConsoleVisible = false;
  bool _useAnalogJoystick = true;
  DateTime? _lastJoystickSendTime;

  void _sendJoystickCommand(double x, double y) {
    final now = DateTime.now();
    if (_lastJoystickSendTime == null ||
        now.difference(_lastJoystickSendTime!) >
            const Duration(milliseconds: 100)) {
      _lastJoystickSendTime = now;
      _btManager.sendCommand('J${x.round()},${y.round()}H\n');
    }
  }

  void _stopJoystick() {
    _btManager.sendCommand('J0,0H\n');
  }

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
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'OTTO DIY',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isConnected
                      ? 'Connected: ${_btManager.connectedDevice!.name}'
                      : 'Disconnected',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isConnected ? const Color(0xFF00E5FF) : Colors.grey,
                  ),
                ),
              ],
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
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: "Classic"),
                          Tab(text: "Wheels"),
                        ],
                        indicatorColor: Color(0xFF00E5FF),
                        labelColor: Color(0xFF00E5FF),
                        unselectedLabelColor: Colors.grey,
                        dividerColor: Colors.white10,
                      ),
                      const SizedBox(height: 12),
                      // Controls Grid
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: TabBarView(
                            children: [
                              // Classic Tab
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Opacity(
                                      opacity: isConnected ? 1.0 : 0.4,
                                      child: AbsorbPointer(
                                        absorbing: !isConnected,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
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
                                            const SizedBox(height: 8),
                                            // Joystick and Speed Slider Side-by-Side
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                // Joystick D-Pad Layout
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // Up
                                                    _JoystickButton(
                                                      icon: Icons
                                                          .keyboard_arrow_up,
                                                      color: const Color(
                                                        0xFF00E5FF,
                                                      ),
                                                      onPressed: () =>
                                                          _btManager.sendCommand(
                                                            'forward${_btManager.speedIndex}\n',
                                                          ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    // Middle Row
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        _JoystickButton(
                                                          icon: Icons
                                                              .keyboard_arrow_left,
                                                          color: const Color(
                                                            0xFF00E5FF,
                                                          ),
                                                          onPressed: () =>
                                                              _btManager
                                                                  .sendCommand(
                                                                    'left${_btManager.speedIndex}\n',
                                                                  ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        _JoystickButton(
                                                          icon: Icons
                                                              .stop_circle_outlined,
                                                          color:
                                                              Colors.redAccent,
                                                          isCenter: true,
                                                          onPressed: () =>
                                                              _btManager
                                                                  .sendCommand(
                                                                    'stop${_btManager.speedIndex}\n',
                                                                  ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        _JoystickButton(
                                                          icon: Icons
                                                              .keyboard_arrow_right,
                                                          color: const Color(
                                                            0xFF00E5FF,
                                                          ),
                                                          onPressed: () =>
                                                              _btManager
                                                                  .sendCommand(
                                                                    'right${_btManager.speedIndex}\n',
                                                                  ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    // Down
                                                    _JoystickButton(
                                                      icon: Icons
                                                          .keyboard_arrow_down,
                                                      color: const Color(
                                                        0xFF00E5FF,
                                                      ),
                                                      onPressed: () =>
                                                          _btManager.sendCommand(
                                                            'backward${_btManager.speedIndex}\n',
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(
                                                  width: 40,
                                                ), // Spacing between joystick and slider
                                                // Vertical Speed Slider Column
                                                SizedBox(
                                                  width: 80,

                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.speed,
                                                        color: Colors.grey,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      const Text(
                                                        'SPEED',
                                                        style: TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          letterSpacing: 1.0,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        _getSpeedLabel(
                                                          _btManager.speedIndex,
                                                        ),
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF00E5FF,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 10,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      SizedBox(
                                                        height: 120,
                                                        child: RotatedBox(
                                                          quarterTurns: 3,
                                                          child: Slider(
                                                            value: _btManager
                                                                .speedIndex
                                                                .toDouble(),
                                                            min: 0,
                                                            max: 5,
                                                            divisions: 5,
                                                            activeColor:
                                                                const Color(
                                                                  0xFF00E5FF,
                                                                ),
                                                            inactiveColor:
                                                                Colors.white10,
                                                            onChanged: (value) {
                                                              _btManager
                                                                      .speedIndex =
                                                                  value.round();
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
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
                                                _SmallButton(
                                                  'Happy',
                                                  Icons.mood,
                                                  Colors.amber,
                                                  () => _btManager.sendCommand(
                                                    'happy2\n',
                                                  ),
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
                                                  () => _btManager.sendCommand(
                                                    'sad2\n',
                                                  ),
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
                                                  () => _btManager.sendCommand(
                                                    'fail2\n',
                                                  ),
                                                ),
                                                _SmallButton(
                                                  'Fart',
                                                  Icons.air,
                                                  Colors.amber,
                                                  () => _btManager.sendCommand(
                                                    'fart2\n',
                                                  ),
                                                ),
                                                _SmallButton(
                                                  'Love',
                                                  Icons.favorite,
                                                  Colors.amber,
                                                  () => _btManager.sendCommand(
                                                    'love2\n',
                                                  ),
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
                                                  () => _btManager.sendCommand(
                                                    'magic2\n',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'SING',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                _SmallButton(
                                                  'Surprise',
                                                  Icons.music_note,
                                                  const Color(0xFFFFB300),
                                                  () => _btManager.sendCommand(
                                                    'sing 6\n',
                                                  ),
                                                ),
                                                _SmallButton(
                                                  'OhOoh',
                                                  Icons.music_note,
                                                  const Color(0xFFFFB300),
                                                  () => _btManager.sendCommand(
                                                    'sing 7\n',
                                                  ),
                                                ),
                                                _SmallButton(
                                                  'OhOoh 2',
                                                  Icons.music_note,
                                                  const Color(0xFFFFB300),
                                                  () => _btManager.sendCommand(
                                                    'sing 8\n',
                                                  ),
                                                ),
                                                _SmallButton(
                                                  'Cuddly',
                                                  Icons.music_note,
                                                  const Color(0xFFFFB300),
                                                  () => _btManager.sendCommand(
                                                    'sing 9\n',
                                                  ),
                                                ),
                                                _SmallButton(
                                                  'Sleeping',
                                                  Icons.music_note,
                                                  const Color(0xFFFFB300),
                                                  () => _btManager.sendCommand(
                                                    'sing 10\n',
                                                  ),
                                                ),
                                                _SmallButton(
                                                  'Happy',
                                                  Icons.music_note,
                                                  const Color(0xFFFFB300),
                                                  () => _btManager.sendCommand(
                                                    'sing 12\n',
                                                  ),
                                                ),
                                                _SmallButton(
                                                  'Sad',
                                                  Icons.music_note,
                                                  const Color(0xFFFFB300),
                                                  () => _btManager.sendCommand(
                                                    'sing 14\n',
                                                  ),
                                                ),
                                                _SmallButton(
                                                  'Confused',
                                                  Icons.music_note,
                                                  const Color(0xFFFFB300),
                                                  () => _btManager.sendCommand(
                                                    'sing 15\n',
                                                  ),
                                                ),
                                                _SmallButton(
                                                  'Fart',
                                                  Icons.music_note,
                                                  const Color(0xFFFFB300),
                                                  () => _btManager.sendCommand(
                                                    'sing 17\n',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
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
                                    Opacity(
                                      opacity: isConnected ? 1.0 : 0.4,
                                      child: AbsorbPointer(
                                        absorbing: !isConnected,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      _ControlButton(
                                                        icon: Icons
                                                            .remove_red_eye,
                                                        label: 'AVOIDANCE',
                                                        color: Colors
                                                            .lightGreenAccent,
                                                        isActive:
                                                            _btManager
                                                                .activeMode ==
                                                            'avoidance',
                                                        onPressed: () {
                                                          if (_btManager
                                                                  .activeMode ==
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
                                                          color:
                                                              Colors.grey[400],
                                                          fontSize: 11,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      _ControlButton(
                                                        icon: Icons
                                                            .sports_martial_arts,
                                                        label: 'USE FORCE',
                                                        color: Colors
                                                            .lightBlueAccent,
                                                        isActive:
                                                            _btManager
                                                                .activeMode ==
                                                            'force',
                                                        onPressed: () {
                                                          if (_btManager
                                                                  .activeMode ==
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
                                                          color:
                                                              Colors.grey[400],
                                                          fontSize: 11,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        Opacity(
                                          opacity: isConnected ? 1.0 : 0.4,
                                          child: AbsorbPointer(
                                            absorbing: !isConnected,
                                            child: _SmallButton(
                                              _btManager.lastDistance != null
                                                  ? 'Distance: ${_btManager.lastDistance!.toStringAsFixed(0)} cm'
                                                  : 'Distance',
                                              Icons.sensors,
                                              Colors.tealAccent,
                                              () => _btManager
                                                  .toggleUltrasoundPolling(),
                                              isActive: _btManager
                                                  .isPollingUltrasound,
                                            ),
                                          ),
                                        ),
                                        Opacity(
                                          opacity: isConnected ? 1.0 : 0.4,
                                          child: AbsorbPointer(
                                            absorbing: !isConnected,
                                            child: _SmallButton(
                                              'Walk Test',
                                              Icons.directions_walk,
                                              Colors.pinkAccent,
                                              () => _btManager.sendCommand(
                                                'walk_test2\n',
                                              ),
                                            ),
                                          ),
                                        ),
                                        Opacity(
                                          opacity: isConnected ? 1.0 : 0.4,
                                          child: AbsorbPointer(
                                            absorbing: !isConnected,
                                            child: _SmallButton(
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
                                          ),
                                        ),
                                        _SmallButton(
                                          'Get Arduino Code',
                                          Icons.download,
                                          Colors.lightBlueAccent,
                                          () {
                                            DownloadHelper.downloadFile(
                                              'https://github.com/Dawied/ottodiy_classic_app/blob/main/firmware/OttoS_BLE_v2/OttoS_BLE_v2.ino',
                                              'OttoS_BLE_v2.ino',
                                            ).catchError((e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Download failed: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Wheels Tab
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Opacity(
                                      opacity: isConnected ? 1.0 : 0.4,
                                      child: AbsorbPointer(
                                        absorbing: !isConnected,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
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
                                                    _SmallButton(
                                                      'Joystick',
                                                      Icons.circle_outlined,
                                                      _useAnalogJoystick
                                                          ? const Color(
                                                              0xFF00E5FF,
                                                            )
                                                          : Colors.grey,
                                                      () => setState(
                                                        () =>
                                                            _useAnalogJoystick =
                                                                true,
                                                      ),
                                                      isActive:
                                                          _useAnalogJoystick,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _SmallButton(
                                                      'D-Pad',
                                                      Icons.grid_3x3,
                                                      _useAnalogJoystick
                                                          ? Colors.grey
                                                          : const Color(
                                                              0xFF00E5FF,
                                                            ),
                                                      () => setState(
                                                        () =>
                                                            _useAnalogJoystick =
                                                                false,
                                                      ),
                                                      isActive:
                                                          !_useAnalogJoystick,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            if (_useAnalogJoystick)
                                              Center(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    8.0,
                                                  ),
                                                  child: _VirtualJoystick(
                                                    onJoystickChanged:
                                                        _sendJoystickCommand,
                                                    onJoystickStop:
                                                        _stopJoystick,
                                                  ),
                                                ),
                                              )
                                            else
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  // Joystick D-Pad Layout
                                                  Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      // Up
                                                      _JoystickButton(
                                                        icon: Icons
                                                            .keyboard_arrow_up,
                                                        color: const Color(
                                                          0xFF00E5FF,
                                                        ),
                                                        onPressed: () =>
                                                            _btManager.sendCommand(
                                                              'forward${_btManager.speedIndex}\n',
                                                            ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      // Middle Row
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          _JoystickButton(
                                                            icon: Icons
                                                                .keyboard_arrow_left,
                                                            color: const Color(
                                                              0xFF00E5FF,
                                                            ),
                                                            onPressed: () =>
                                                                _btManager
                                                                    .sendCommand(
                                                                      'left${_btManager.speedIndex}\n',
                                                                    ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          _JoystickButton(
                                                            icon: Icons
                                                                .stop_circle_outlined,
                                                            color: Colors
                                                                .redAccent,
                                                            isCenter: true,
                                                            onPressed: () =>
                                                                _btManager
                                                                    .sendCommand(
                                                                      'stop${_btManager.speedIndex}\n',
                                                                    ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          _JoystickButton(
                                                            icon: Icons
                                                                .keyboard_arrow_right,
                                                            color: const Color(
                                                              0xFF00E5FF,
                                                            ),
                                                            onPressed: () =>
                                                                _btManager
                                                                    .sendCommand(
                                                                      'right${_btManager.speedIndex}\n',
                                                                    ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      // Down
                                                      _JoystickButton(
                                                        icon: Icons
                                                            .keyboard_arrow_down,
                                                        color: const Color(
                                                          0xFF00E5FF,
                                                        ),
                                                        onPressed: () =>
                                                            _btManager.sendCommand(
                                                              'backward${_btManager.speedIndex}\n',
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    width: 40,
                                                  ), // Spacing between joystick and slider
                                                  // Vertical Speed Slider Column
                                                  SizedBox(
                                                    width: 80,

                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.speed,
                                                          color: Colors.grey,
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        const Text(
                                                          'SPEED',
                                                          style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            letterSpacing: 1.0,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          _getSpeedLabel(
                                                            _btManager
                                                                .speedIndex,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFF00E5FF,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 10,
                                                              ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        SizedBox(
                                                          height: 120,
                                                          child: RotatedBox(
                                                            quarterTurns: 3,
                                                            child: Slider(
                                                              value: _btManager
                                                                  .speedIndex
                                                                  .toDouble(),
                                                              min: 0,
                                                              max: 5,
                                                              divisions: 5,
                                                              activeColor:
                                                                  const Color(
                                                                    0xFF00E5FF,
                                                                  ),
                                                              inactiveColor:
                                                                  Colors
                                                                      .white10,
                                                              onChanged: (value) {
                                                                _btManager
                                                                        .speedIndex =
                                                                    value
                                                                        .round();
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
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
                                                        icon: Icons
                                                            .remove_red_eye,
                                                        label: 'AVOIDANCE',
                                                        color: Colors
                                                            .lightGreenAccent,
                                                        isActive:
                                                            _btManager
                                                                .activeMode ==
                                                            'avoidance',
                                                        onPressed: () {
                                                          if (_btManager
                                                                  .activeMode ==
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
                                                        'Otto starts driving and avoids obstacles',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[400],
                                                          fontSize: 11,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      _ControlButton(
                                                        icon: Icons.navigation,
                                                        label: 'LINE FOLLOWER',
                                                        color: Colors
                                                            .lightBlueAccent,
                                                        isActive:
                                                            _btManager
                                                                .activeMode ==
                                                            'line_follower',
                                                        onPressed: () {
                                                          if (_btManager
                                                                  .activeMode ==
                                                              'line_follower') {
                                                            _btManager.sendCommand(
                                                              'stop${_btManager.speedIndex}\n',
                                                            );
                                                          } else {
                                                            _btManager.sendCommand(
                                                              'line_follower${_btManager.speedIndex}\n',
                                                            );
                                                          }
                                                        },
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        'Otto follows lines on the ground',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[400],
                                                          fontSize: 11,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
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
                                          'Get Arduino Code',
                                          Icons.download,
                                          Colors.lightBlueAccent,
                                          () {
                                            DownloadHelper.downloadFile(
                                              'https://github.com/Dawied/ottodiy_classic_app/blob/main/firmware/OttoW_BLE_v2/OttoW_BLE_v2.ino',
                                              'OttoW_BLE_v2.ino',
                                            ).catchError((e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Download failed: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Console / Serial Logs
                      if (_isConsoleVisible) ...[
                        const SizedBox(height: 16),
                        Expanded(
                          flex: 1,
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
          width: 45,
          height: 45,
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

class _VirtualJoystick extends StatefulWidget {
  final Function(double x, double y) onJoystickChanged;
  final VoidCallback onJoystickStop;

  const _VirtualJoystick({
    required this.onJoystickChanged,
    required this.onJoystickStop,
  });

  @override
  State<_VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<_VirtualJoystick> {
  Offset _dragPosition = Offset.zero;
  final double _joystickRadius = 60.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        final renderBox = context.findRenderObject() as RenderBox;
        final localOffset = renderBox.globalToLocal(details.globalPosition);
        final center = Offset(
          renderBox.size.width / 2,
          renderBox.size.height / 2,
        );
        Offset offset = localOffset - center;

        // Clamp offset to joystick radius
        if (offset.distance > _joystickRadius) {
          offset = Offset.fromDirection(offset.direction, _joystickRadius);
        }

        setState(() {
          _dragPosition = offset;
        });

        // Normalize values to -50 to 50
        double normalizedX = (offset.dx / _joystickRadius) * 50.0;
        double normalizedY = -(offset.dy / _joystickRadius) * 50.0;

        widget.onJoystickChanged(normalizedX, normalizedY);
      },
      onPanEnd: (_) {
        setState(() {
          _dragPosition = Offset.zero;
        });
        widget.onJoystickStop();
      },
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Background Ring
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            // Center indicator
            Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Joystick thumb
            Positioned(
              left: 70.0 + _dragPosition.dx - 25.0,
              top: 70.0 + _dragPosition.dy - 25.0,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    // Floating Z-elevation shadow
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.drag_indicator,
                  color: Colors.black54,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
