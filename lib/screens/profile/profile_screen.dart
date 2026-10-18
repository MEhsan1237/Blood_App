import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../utils/constants.dart';
import '../../widgets/circle_icon.dart';
import '../../models/user_model.dart';
import '../../models/badge_model.dart';
import '../../widgets/badge_widgets.dart';
import '../auth/login_screen.dart';
import 'edit_profile_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _updateRole(UserModel user, String newRole) async {
    if (user.role == newRole) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'role': newRole,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${newRole.toUpperCase()} profile'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.primary),
        );
      }
    }
  }

  void _showBadgeDetails(BuildContext context, BadgeTier tier, UserModel user) {
    final isUnlocked = user.totalDonations >= tier.minDonations &&
        user.loyaltyPoints >= tier.minPoints &&
        (!tier.requireInAppPercentage || user.inAppDonations >= (tier.minDonations * 0.5));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserBadgeIcon(tier: tier, size: 80, isLocked: !isUnlocked),
            const SizedBox(height: 16),
            Text(
              tier.name, 
              style: TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.bold, 
                color: isUnlocked ? tier.color : Colors.grey,
              )
            ),
            const SizedBox(height: 24),
            _buildMinimalProgressBar(
              label: 'Donations',
              current: user.totalDonations,
              target: tier.minDonations,
              color: tier.color,
            ),
            const SizedBox(height: 12),
            _buildMinimalProgressBar(
              label: 'Points',
              current: user.loyaltyPoints,
              target: tier.minPoints,
              color: tier.color,
            ),
            if (tier.requireInAppPercentage) ...[
               const SizedBox(height: 12),
               _buildMinimalProgressBar(
                label: 'In-App Donations (Min 50%)',
                current: user.inAppDonations,
                target: (tier.minDonations * 0.5).toInt(),
                color: tier.color,
              ),
            ],
            const SizedBox(height: 24),
            Text(
              isUnlocked 
                ? 'Achievement Unlocked!' 
                : 'Keep going to unlock this badge!',
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final hPadding = AppSpacing.horizontalPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _showLogoutDialog(context, authService),
          ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: authService.userDataStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data;
          if (user == null) return const Center(child: Text('User not found'));

          final currentTier = BadgeTiers.getCurrentTier(
            user.totalDonations,
            user.loyaltyPoints,
            user.inAppDonations,
          );
          final nextTier = BadgeTiers.getNextTier(
            user.totalDonations,
            user.loyaltyPoints,
            user.inAppDonations,
          );

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Minimal Header
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: AppColors.accent,
                            child: Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                          if (currentTier != null)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: UserBadgeIcon(tier: currentTier, size: 30),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (currentTier != null)
                        Text(
                          currentTier.name,
                          style: TextStyle(
                            color: currentTier.color, 
                            fontWeight: FontWeight.w600, 
                            fontSize: 14,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${user.bloodGroup} | ${user.city}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Compact Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Points', user.loyaltyPoints.toString()),
                    _buildStatItem('Donations', user.totalDonations.toString()),
                    _buildStatItem('Blood', user.bloodGroup),
                  ],
                ),
                const SizedBox(height: 32),

                // Role Switcher - Moved above Achievements
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildRoleButton(
                          title: 'Donor',
                          isSelected: user.role == 'donor',
                          onTap: () => _updateRole(user, 'donor'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildRoleButton(
                          title: 'Receiver',
                          isSelected: user.role == 'receiver',
                          onTap: () => _updateRole(user, 'receiver'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Achievements - Minimal Horizontal List
                const Text('Achievements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: BadgeTiers.all.length,
                    itemBuilder: (context, index) {
                      final tier = BadgeTiers.all[index];
                      final isUnlocked = user.totalDonations >= tier.minDonations &&
                          user.loyaltyPoints >= tier.minPoints &&
                          (!tier.requireInAppPercentage || user.inAppDonations >= (tier.minDonations * 0.5));

                      return CompactBadgeItem(
                        tier: tier,
                        isUnlocked: isUnlocked,
                        onTap: () => _showBadgeDetails(context, tier, user),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Next Goal - Integrated Progress
                if (nextTier != currentTier) ...[
                  const Text('Next Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            UserBadgeIcon(tier: nextTier, size: 30, isLocked: true),
                            const SizedBox(width: 8),
                            Text('Unlock ${nextTier.name}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildMinimalProgressBar(
                          label: 'Donations',
                          current: user.totalDonations,
                          target: nextTier.minDonations,
                          color: nextTier.color,
                        ),
                        const SizedBox(height: 8),
                        _buildMinimalProgressBar(
                          label: 'Points',
                          current: user.loyaltyPoints,
                          target: nextTier.minPoints,
                          color: nextTier.color,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                const Divider(),
                
                // Settings & Actions
                _buildProfileTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark Mode',
                  trailing: Switch(
                    value: themeProvider.themeMode == ThemeMode.dark,
                    onChanged: (val) => themeProvider.toggleTheme(),
                    activeColor: AppColors.primary,
                  ),
                ),
                _buildProfileTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit Profile',
                  onTap: () => _showEditProfileSheet(context, user),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoleButton({required String title, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalProgressBar({required String label, required int current, required int target, required Color color}) {
    double progress = (current / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text('$current/$target', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTile({required IconData icon, required String title, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, size: 22, color: Colors.grey[700]),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      dense: true,
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await authService.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => EditProfileSheet(user: user),
    );
  }
}
