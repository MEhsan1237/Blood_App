import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// A professional circular icon widget following the project's design rule.
/// [icon] is the IconData to display.
/// [size] is the diameter of the circle.
/// [color] is the color of the icon.
class CircleIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const CircleIcon({
    super.key,
    required this.icon,
    this.size = 50,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.circleIconBg,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color ?? AppColors.primary,
        size: size * 0.5,
      ),
    );
  }
}
