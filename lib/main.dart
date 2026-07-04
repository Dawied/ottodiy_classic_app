import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_manager.dart';
import 'widgets/gestures_panel.dart';
import 'widgets/songs_panel.dart';
import 'widgets/classic_utilities.dart';
import 'widgets/wheels_utilities.dart';
import 'widgets/walk_section.dart';
import 'widgets/classic_modes_section.dart';
import 'widgets/drive_section.dart';
import 'widgets/wheels_modes_section.dart';
import 'widgets/connection_modal.dart';

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

  void _showConnectionModal() {
    if (!_btManager.isScanning && _btManager.connectedDevice == null) {
      _btManager.startScan();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ConnectionModal(btManager: _btManager),
    );
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
                                            WalkSection(btManager: _btManager),
                                            const SizedBox(height: 12),
                                            GesturesPanel(
                                              btManager: _btManager,
                                            ),
                                            const SizedBox(height: 12),
                                            SongsPanel(btManager: _btManager),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ClassicModesSection(btManager: _btManager),
                                    const SizedBox(height: 24),
                                    ClassicUtilities(btManager: _btManager),
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
                                    DriveSection(btManager: _btManager),
                                    const SizedBox(height: 24),
                                    WheelsModesSection(btManager: _btManager),
                                    const SizedBox(height: 24),
                                    const WheelsUtilities(),
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
