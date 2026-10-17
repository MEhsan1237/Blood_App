import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/circle_icon.dart';
import 'add_donation_sheet.dart';

/// Screen displaying the user's donation history.
class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final hPadding = AppSpacing.horizontalPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation History'),
      ),
      body: FutureBuilder(
        future: authService.getUserData(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = userSnapshot.data;
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('donations')
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final donations = snapshot.data?.docs ?? [];

              if (donations.isEmpty) {
                return _buildEmptyState();
              }

              // Key Fix: Using Builder to ensure theme updates properly
              return Builder(
                builder: (BuildContext innerContext) {
                  return ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: hPadding,
                      vertical: 20,
                    ),
                    itemCount: donations.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 15),
                    itemBuilder: (context, index) {
                      final data = donations[index].data() as Map<String, dynamic>;
                      return _buildDonationCard(innerContext, data);
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'donate_fab',
        onPressed: () => _showAddDonationSheet(context, authService),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Record Donation', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  /// UI shown when no donations have been recorded.
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleIcon(icon: Icons.volunteer_activism, size: 80),
          SizedBox(height: 16),
          Text('No donations recorded yet.', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 8),
          Text('Be a hero, save a life!', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Individual donation record card - Now properly theme aware
  Widget _buildDonationCard(BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final DateTime date = DateTime.parse(data['date'] as String);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.35 : 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Hospital Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(
                theme.brightness == Brightness.dark ? 0.18 : 0.12,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_hospital_outlined,
              color: AppColors.primary,
              size: 26,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['hospital'] ?? 'Unknown Hospital',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // Points Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '+50 PTS',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Earned',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Opens the bottom sheet to add a donation.
  void _showAddDonationSheet(BuildContext context, AuthService authService) async {
    final user = await authService.getUserData();
    if (user != null && context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => AddDonationSheet(userId: user.uid),
      );
    }
  }
}