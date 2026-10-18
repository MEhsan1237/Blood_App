import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/circle_icon.dart';
import '../chat/chat_screen.dart';
import '../requests/requests_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hPadding = AppSpacing.horizontalPadding(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        shape: Border(
          bottom: BorderSide(
            color: AppColors.divider.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: authService.currentUser?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final notifications = snapshot.data!.docs.toList();
          notifications.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTs = _getTimestamp(aData['timestamp']);
            final bTs = _getTimestamp(bData['timestamp']);
            return bTs.compareTo(aTs);
          });

          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final docId = doc.id;
              
              if (data['type'] == 'blood_request') {
                return _buildUrgentRequestCard(context, data, docId);
              }
              return _buildMinimalItem(context, data, docId);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80, color: theme.disabledColor.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('No new notifications', style: TextStyle(color: theme.disabledColor, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMinimalItem(BuildContext context, Map<String, dynamic> item, String docId) {
    final isRead = item['isRead'] == true;
    final timestamp = _getTimestamp(item['timestamp']);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    IconData iconData;
    switch (item['type']) {
      case 'donation_interest':
        iconData = Icons.chat_bubble_outline_rounded;
        break;
      case 'donation_confirmed':
        iconData = Icons.verified_user_outlined;
        break;
      default:
        iconData = Icons.notifications_none_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => _handleNotificationTap(context, item, docId),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isRead ? Colors.transparent : theme.primaryColor.withOpacity(isDark ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? theme.dividerColor.withOpacity(0.1) : theme.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isRead)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                const SizedBox(width: 8),
              const SizedBox(width: 12),
              CircleIcon(
                icon: iconData, 
                size: 36, 
                color: isRead ? theme.disabledColor : theme.primaryColor
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['message'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: isRead ? theme.textTheme.bodyMedium?.color?.withOpacity(0.6) : theme.textTheme.bodyMedium?.color,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getTimeAgo(timestamp),
                      style: TextStyle(color: theme.disabledColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrgentRequestCard(BuildContext context, Map<String, dynamic> item, String docId) {
    final timestamp = _getTimestamp(item['timestamp']);
    final data = item['data'] ?? {};
    final requestId = data['requestId'];
    final bloodGroup = data['bloodGroup'] ?? '??';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (requestId == null) {
      return _buildMinimalItem(context, item, docId);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('requests').doc(requestId).snapshots(),
      builder: (context, snapshot) {
        bool isCompleted = false;
        String city = data['city'] ?? '...';
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final reqData = snapshot.data!.data() as Map<String, dynamic>;
          isCompleted = reqData['status'] != 'Open';
          city = reqData['city'] ?? city;
        } else if (snapshot.hasData && !snapshot.data!.exists) {
          isCompleted = true;
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? theme.cardColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isCompleted 
                    ? Colors.black.withOpacity(0.05)
                    : theme.primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: isCompleted 
                  ? theme.dividerColor.withOpacity(0.2) 
                  : theme.primaryColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCompleted 
                        ? [Colors.grey[600]!, Colors.grey[500]!]
                        : [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle_outline : Icons.emergency_rounded, 
                      color: Colors.white, 
                      size: 18
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isCompleted ? 'REQUEST CLOSED' : 'URGENT BLOOD REQUEST',
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 12, 
                          letterSpacing: 1.1
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        bloodGroup,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCompleted 
                        ? 'Request accepted by the user for $bloodGroup blood in $city.'
                        : (item['message'] ?? 'Immediate blood donation is required.'),
                      style: TextStyle(
                        fontSize: 14, 
                        height: 1.4, 
                        color: isCompleted ? theme.disabledColor : theme.textTheme.bodyLarge?.color, 
                        fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: theme.disabledColor),
                            const SizedBox(width: 6),
                            Text(
                              _getTimeAgo(timestamp),
                              style: TextStyle(color: theme.disabledColor, fontSize: 12),
                            ),
                          ],
                        ),
                        if (isCompleted)
                          TextButton.icon(
                            onPressed: () => _handleContact(context, item, docId),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                            label: const Text('Contact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.primaryColor,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                      ],
                    ),
                    if (!isCompleted) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _handleContact(context, item, docId),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: theme.dividerColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text('Contact', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _handleAccept(context, item, docId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text('Accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  DateTime _getTimestamp(dynamic ts) {
    if (ts == null) return DateTime.now();
    if (ts is Timestamp) return ts.toDate();
    if (ts is String) {
      try {
        return DateTime.parse(ts);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  String _getTimeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 0) return '${duration.inDays}d ago';
    if (duration.inHours > 0) return '${duration.inHours}h ago';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ago';
    return 'Just now';
  }

  void _handleNotificationTap(BuildContext context, Map<String, dynamic> item, String docId) async {
    FirebaseFirestore.instance.collection('notifications').doc(docId).update({'isRead': true});

    if (item['type'] == 'donation_interest') {
      _handleContact(context, item, docId);
    } else if (item['type'] == 'blood_request') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const RequestsScreen()));
    }
  }

  void _handleContact(BuildContext context, Map<String, dynamic> item, String docId) async {
    FirebaseFirestore.instance.collection('notifications').doc(docId).update({'isRead': true});
    
    final data = item['data'] ?? {};
    final requestId = data['requestId'];
    if (requestId == null) return;

    String targetUserId;
    String targetUserName;
    String myRole;

    if (item['type'] == 'donation_interest') {
      // I am the requester (receiver), I want to contact the donor
      targetUserId = data['donorId'];
      myRole = 'receiver';
      
      // Fetch donor name from users collection
      final donorDoc = await FirebaseFirestore.instance.collection('users').doc(targetUserId).get();
      targetUserName = donorDoc.exists ? (donorDoc.data() as Map<String, dynamic>)['name'] : 'Donor';
    } else {
      // I am the donor, I want to contact the requester
      final requestDoc = await FirebaseFirestore.instance.collection('requests').doc(requestId).get();
      if (!requestDoc.exists) return;

      final requestData = requestDoc.data()!;
      targetUserId = requestData['requesterId'];
      targetUserName = requestData['requesterName'];
      myRole = 'donor';
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            receiverId: targetUserId,
            receiverName: targetUserName,
            myRole: myRole,
            requestId: requestId,
          ),
        ),
      );
    }
  }

  void _handleAccept(BuildContext context, Map<String, dynamic> item, String docId) async {
    FirebaseFirestore.instance.collection('notifications').doc(docId).update({'isRead': true});
    
    if (context.mounted) {
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (context) => const RequestsScreen())
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Interested! Please view the request to proceed.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}
