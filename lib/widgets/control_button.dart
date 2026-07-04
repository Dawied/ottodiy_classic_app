import 'package:flutter/material.dart';
import 'hover_scale.dart';

class ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool isActive;

  const ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return HoverScale(
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
