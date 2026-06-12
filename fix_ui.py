import re

file_path = "d:/Project/OttoDiyApp/App/ottodiy_flutter/lib/main.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

start_marker = r"// Controls Grid"
end_marker = r"// Console / Serial Logs"

new_block = """// Controls Grid
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
                                'MOVEMENT',
                                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
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
                                      onPressed: () => _btManager.sendCommand('forward2\\n'),
                                    ),
                                    const SizedBox(height: 8),
                                    // Middle Row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _JoystickButton(
                                          icon: Icons.keyboard_arrow_left,
                                          color: const Color(0xFF00E5FF),
                                          onPressed: () => _btManager.sendCommand('left2\\n'),
                                        ),
                                        const SizedBox(width: 8),
                                        _JoystickButton(
                                          icon: Icons.stop_circle_outlined,
                                          color: Colors.redAccent,
                                          isCenter: true,
                                          onPressed: () => _btManager.sendCommand('stop2\\n'),
                                        ),
                                        const SizedBox(width: 8),
                                        _JoystickButton(
                                          icon: Icons.keyboard_arrow_right,
                                          color: const Color(0xFF00E5FF),
                                          onPressed: () => _btManager.sendCommand('right2\\n'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Down
                                    _JoystickButton(
                                      icon: Icons.keyboard_arrow_down,
                                      color: const Color(0xFF00E5FF),
                                      onPressed: () => _btManager.sendCommand('backward2\\n'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'GESTURES',
                                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _SmallButton('Happy', Icons.mood, Colors.amber, () => _btManager.sendCommand('happy2\\n')),
                                  _SmallButton('Victory', Icons.emoji_events, Colors.amber, () => _btManager.sendCommand('victory2\\n')),
                                  _SmallButton('Sad', Icons.mood_bad, Colors.amber, () => _btManager.sendCommand('sad2\\n')),
                                  _SmallButton('Sleep', Icons.hotel, Colors.amber, () => _btManager.sendCommand('sleeping2\\n')),
                                  _SmallButton('Confused', Icons.question_mark, Colors.amber, () => _btManager.sendCommand('confused2\\n')),
                                  _SmallButton('Fail', Icons.error_outline, Colors.amber, () => _btManager.sendCommand('fail2\\n')),
                                  _SmallButton('Fart', Icons.air, Colors.amber, () => _btManager.sendCommand('fart2\\n')),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'MODES',
                                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ControlButton(
                                      icon: Icons.remove_red_eye,
                                      label: 'AVOIDANCE',
                                      color: Colors.lightGreenAccent,
                                      onPressed: () => _btManager.sendCommand('avoidance2\\n'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _ControlButton(
                                      icon: Icons.sports_martial_arts,
                                      label: 'USE FORCE',
                                      color: Colors.lightBlueAccent,
                                      onPressed: () => _btManager.sendCommand('force2\\n'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'UTILITIES',
                                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _SmallButton('Ultrasound', Icons.sensors, Colors.tealAccent, () => _btManager.sendCommand('ultrasound2\\n')),
                                  _SmallButton('Walk Test', Icons.directions_walk, Colors.pinkAccent, () => _btManager.sendCommand('walk_test2\\n')),
                                  _SmallButton('Calibrate', Icons.build, Colors.orangeAccent, () => _btManager.sendCommand('C2\\n')),
                                  _SmallButton('Save Calib.', Icons.save, Colors.greenAccent, () => _btManager.sendCommand('save_calibration2\\n')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                """

pattern = re.compile(start_marker + r".*?(?=" + end_marker + ")", re.DOTALL)
new_content = pattern.sub(new_block, content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(new_content)
