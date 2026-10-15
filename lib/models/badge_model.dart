import 'package:flutter/material.dart';

class BadgeTier {
  final String name;
  final int minDonations;
  final int minPoints;
  final Color color;
  final IconData icon;
  final bool requireInAppPercentage;

  const BadgeTier({
    required this.name,
    required this.minDonations,
    required this.minPoints,
    required this.color,
    required this.icon,
    this.requireInAppPercentage = false,
  });
}

class BadgeTiers {
  static const List<BadgeTier> all = [
    BadgeTier(
      name: 'Life Saver',
      minDonations: 1,
      minPoints: 100,
      color: Color(0xFFCD7F32), // Bronze
      icon: Icons.volunteer_activism,
    ),
    BadgeTier(
      name: 'Helping Hero',
      minDonations: 2,
      minPoints: 200,
      color: Color(0xFF757575), // Silver (Grey 600)
      icon: Icons.favorite,
    ),
    BadgeTier(
      name: 'Blood Champion',
      minDonations: 5,
      minPoints: 500,
      color: Color(0xFFE65100), // Vibrant Burnt Orange (High contrast, attractive in both themes)
      icon: Icons.star,
    ),
    BadgeTier(
      name: 'Guardian Angel',
      minDonations: 10,
      minPoints: 1000,
      color: Color(0xFF0097A7), // Deep Cyan
      icon: Icons.security,
    ),
    BadgeTier(
      name: 'Hope Bringer',
      minDonations: 15,
      minPoints: 1500,
      color: Color(0xFF3F51B5), // Indigo
      icon: Icons.wb_sunny,
    ),
    BadgeTier(
      name: 'Community Pillar',
      minDonations: 20,
      minPoints: 2000,
      color: Color(0xFFC62828), // Deep Red
      icon: Icons.account_balance,
    ),
    BadgeTier(
      name: 'Legendary Donor',
      minDonations: 25,
      minPoints: 3000,
      color: Color(0xFF7B1FA2), // Purple
      icon: Icons.workspace_premium,
    ),
    BadgeTier(
      name: 'Platinum Life Saver',
      minDonations: 40,
      minPoints: 5000,
      color: Color(0xFF455A64), // Blue Grey
      icon: Icons.diamond,
      requireInAppPercentage: true,
    ),
  ];

  static BadgeTier? getCurrentTier(int donations, int points, int inAppDonations) {
    BadgeTier? current;
    for (var tier in all) {
      bool meetsDonations = donations >= tier.minDonations;
      bool meetsPoints = points >= tier.minPoints;
      bool meetsInApp = !tier.requireInAppPercentage || (inAppDonations >= tier.minDonations * 0.5);

      if (meetsDonations && meetsPoints && meetsInApp) {
        current = tier;
      } else {
        break;
      }
    }
    return current;
  }

  static BadgeTier getNextTier(int donations, int points, int inAppDonations) {
    for (var tier in all) {
      bool meetsDonations = donations >= tier.minDonations;
      bool meetsPoints = points >= tier.minPoints;
      bool meetsInApp = !tier.requireInAppPercentage || (inAppDonations >= tier.minDonations * 0.5);

      if (!(meetsDonations && meetsPoints && meetsInApp)) {
        return tier;
      }
    }
    return all.last;
  }
}
