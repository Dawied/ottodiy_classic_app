import 'package:flutter/material.dart';
import 'hover_scale.dart';

class JoystickButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isCenter;

  const JoystickButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    return HoverScale(
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
