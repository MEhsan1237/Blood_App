import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../models/blood_request_model.dart';
import '../../models/badge_model.dart';
import '../../utils/constants.dart';
import '../../widgets/circle_icon.dart';
import '../../widgets/badge_widgets.dart';
import '../requests/requests_screen.dart';
import '../requests/create_request_sheet.dart';
import '../requests/my_requests_screen.dart';
import '../requests/request_details_sheet.dart';
import '../donate/donate_screen.dart';
import '../notifications/notifications_screen.dart';
import '../chat/chat_screen.dart';
import 'find_donors_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final hPadding = AppSpacing.horizontalPadding(context);
    final vPadding = AppSpacing.verticalPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: RichText(

          text: TextSpan(
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
            children: [
              const TextSpan(
                text: 'BLOOD',
                style: TextStyle(color: AppColors.primary),
              ),
              TextSpan(
                text: 'CONNECT',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        actions: [
          _buildNotificationIcon(context, authService),
        ],
        elevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: AppColors.divider.withOpacity(0.7),
            width: 1,
          ),
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: authService.userDataStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final user = snapshot.data;
          if (user == null) return const Center(child: Text('User not found'));

          final isDonor = user.role == 'donor';

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(user),
                const SizedBox(height: 24),
                
                // 1. Recovery Card (Donors only)
                if (isDonor) ...[
                  _buildRecoveryCard(context, user),
                  const SizedBox(height: 24),
                ],
                
                // 2. Loyalty Points (Everyone)
                _buildLoyaltySection(user),
                
                // 3. Role-specific content
                if (isDonor) ...[
                  // Donor View: Just Recent Requests
                  const SizedBox(height: 32),
                  _buildDonorRecentRequests(context),
                ] else ...[
                  // Receiver View: Quick Actions then Top Donors
                  const SizedBox(height: 32),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildQuickActions(context),
                  const SizedBox(height: 32),
                  _buildTopDonorsSection(context, user),
                ],
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(UserModel user) {
    final currentTier = BadgeTiers.getCurrentTier(
      user.totalDonations,
      user.loyaltyPoints,
      user.inAppDonations,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Hello, ${user.name}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (currentTier != null) ...[
                    const SizedBox(width: 8),
                    UserBadgeIcon(tier: currentTier, size: 20),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                    ),
                  ),
                  if (currentTier != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      currentTier.name,
                      style: TextStyle(
                        color: currentTier.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
          ),
          child: CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.accent,
            child: Text(user.name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 22)),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationIcon(BuildContext context, AuthService authService) {
    final currentUserId = authService.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, size: 28),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRecoveryCard(BuildContext context, UserModel user) {
    int daysRemaining = 0;
    double progress = 1.0;
    
    if (user.recoveryUntil != null) {
      final difference = user.recoveryUntil!.difference(DateTime.now()).inDays;
      daysRemaining = difference > 0 ? difference : 0;
      progress = (90 - daysRemaining).clamp(0, 90) / 90;
    } else if (user.lastDonationDate != null) {
      final difference = DateTime.now().difference(user.lastDonationDate!).inDays;
      daysRemaining = 90 - difference;
      if (daysRemaining < 0) daysRemaining = 0;
      progress = (90 - daysRemaining) / 90;
    }

    bool isEligible = daysRemaining == 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: (isEligible ? AppColors.success : AppColors.primary).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recovery Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isEligible ? AppColors.success : AppColors.warning).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isEligible ? 'Eligible' : 'Recovering',
                  style: TextStyle(
                    color: isEligible ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isEligible 
                          ? [AppColors.success, const Color(0xFF66BB6A)] 
                          : [AppColors.primary, const Color(0xFFEF5350)],
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Icon(
                isEligible ? Icons.check_circle_rounded : Icons.timer_rounded,
                size: 18,
                color: isEligible ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isEligible ? 'You are ready to donate blood!' : '$daysRemaining days until next donation',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoyaltySection(UserModel user) {
    final currentTier = BadgeTiers.getCurrentTier(
      user.totalDonations,
      user.loyaltyPoints,
      user.inAppDonations,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),


              ),
              child: const CircleIcon(icon: Icons.stars_rounded, color: AppColors.primary, size: 60)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Loyalty Points', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              Text('${user.loyaltyPoints} PTS', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          // if (currentTier != null)
          //   UserBadgeIcon(tier: currentTier, size: 36),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionItem(context, Icons.person_search_rounded, 'Find Donors', () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const FindDonorsScreen()));
        }),
        _buildActionItem(context, Icons.add_circle_rounded, 'Request', () {
          showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) => const CreateRequestSheet());
        }),
        _buildActionItem(context, Icons.history_rounded, 'My Requests', () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const MyRequestsScreen()));
        }),
      ],
    );
  }

  Widget _buildActionItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            CircleIcon(icon: icon, size: 56),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDonorRecentRequests(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Blood Requests',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('requests')
              .where('status', isEqualTo: 'Open')
              .orderBy('date', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyRequests(context);
            }

            final requests = snapshot.data!.docs.map((doc) {
              return BloodRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            }).toList();

            return Column(
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requests.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildMinimalRequestCard(context, requests[index]);
                  },
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RequestsScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.05),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All Requests',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyRequests(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.bloodtype_outlined, color: Colors.grey[400], size: 48),
          const SizedBox(height: 12),
          Text('No active requests found.', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMinimalRequestCard(BuildContext context, BloodRequest request) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color groupColor = AppColors.getBloodGroupColor(request.bloodGroup);
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
        border: Border.all(color: AppColors.divider.withOpacity(isDark ? 0.1 : 0.6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => RequestDetailsSheet(request: request),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: groupColor.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: groupColor.withOpacity(isDark ? 0.4 : 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      request.bloodGroup,
                      style: TextStyle(
                        color: groupColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.requesterName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${request.hospital}, ${request.city}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildUrgencySmallBadge(request.urgency),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrgencySmallBadge(String urgency) {
    Color color;
    switch (urgency.toLowerCase()) {
      case 'high':
        color = AppColors.primary;
        break;
      case 'medium':
        color = AppColors.warning;
        break;
      default:
        color = AppColors.success;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        urgency,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildTopDonorsSection(BuildContext context, UserModel currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Eligible Top Donors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FindDonorsScreen()),
                );
              },
              child: const Text('See All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'donor')
              .where('agreeToDonate', isEqualTo: true)
              .orderBy('loyaltyPoints', descending: true)
              .limit(15) // Fetch more to filter in memory
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Text('No eligible donors found.', style: TextStyle(color: Colors.grey));
            }

            final now = DateTime.now();
            final donors = snapshot.data!.docs
                .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
                .where((donor) {
                  if (donor.uid == currentUser.uid) return false;
                  if (donor.recoveryUntil == null) return true;
                  return donor.recoveryUntil!.isBefore(now);
                })
                .take(5)
                .toList();

            if (donors.isEmpty) {
              return const Text('No eligible donors found.', style: TextStyle(color: Colors.grey));
            }

            return Column(
              children: donors.map((donor) => _buildDonorMinimalCard(context, donor, currentUser.role)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDonorMinimalCard(BuildContext context, UserModel donor, String myRole) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTier = BadgeTiers.getCurrentTier(
      donor.totalDonations,
      donor.loyaltyPoints,
      donor.inAppDonations
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withOpacity(isDark ? 0.1 : 0.6)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  receiverId: donor.uid,
                  receiverName: donor.name,
                  myRole: myRole,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      donor.bloodGroup,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              donor.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (currentTier != null) ...[
                            const SizedBox(width: 6),
                            UserBadgeIcon(tier: currentTier, size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentTier?.name ?? 'Life Saver',
                        style: TextStyle(
                          color: currentTier?.color ?? Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 2),
                          Text(
                            donor.city,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.volunteer_activism_rounded, size: 12, color: AppColors.success),
                          const SizedBox(width: 2),
                          Text(
                            '${donor.totalDonations} Donations',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            receiverId: donor.uid,
                            receiverName: donor.name,
                            myRole: myRole,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
