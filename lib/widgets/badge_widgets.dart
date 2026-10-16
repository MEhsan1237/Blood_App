import 'package:flutter/material.dart';
import '../models/badge_model.dart';

class UserBadgeIcon extends StatelessWidget {
  final BadgeTier? tier;
  final double size;
  final bool isLocked;

  const UserBadgeIcon({
    super.key,
    required this.tier,
    this.size = 24,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    if (tier == null) return const SizedBox.shrink();

    final Color color = isLocked ? Colors.grey.withOpacity(0.4) : tier!.color;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        shape: BoxShape.circle,
        border: Border.all(
          color: isLocked ? Colors.grey.withOpacity(0.1) : color.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          tier!.icon,
          size: size * 0.5,
          color: color,
        ),
      ),
    );
  }
}

class CompactBadgeItem extends StatelessWidget {
  final BadgeTier tier;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const CompactBadgeItem({
    super.key,
    required this.tier,
    required this.isUnlocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserBadgeIcon(
              tier: tier,
              size: 48,
              isLocked: !isUnlocked,
            ),
            const SizedBox(height: 6),
            Text(
              tier.name.split(' ').first,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isUnlocked ? FontWeight.w600 : FontWeight.normal,
                color: isUnlocked ? tier.color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
