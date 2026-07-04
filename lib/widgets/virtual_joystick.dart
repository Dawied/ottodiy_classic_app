import 'package:flutter/material.dart';

class VirtualJoystick extends StatefulWidget {
  final Function(double x, double y) onJoystickChanged;
  final VoidCallback onJoystickStop;

  const VirtualJoystick({
    super.key,
    required this.onJoystickChanged,
    required this.onJoystickStop,
  });

  @override
  State<VirtualJoystick> createState() => VirtualJoystickState();
}

class VirtualJoystickState extends State<VirtualJoystick> {
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
