import 'package:flutter/material.dart';
import 'hover_scale.dart';

class SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isActive;

  const SmallButton(
    this.label,
    this.icon,
    this.color,
    this.onPressed, {
    super.key,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return HoverScale(
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
