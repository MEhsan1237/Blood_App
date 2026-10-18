import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/blood_request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../utils/constants.dart';
import '../../widgets/circle_icon.dart';
import '../chat/chat_screen.dart';
import 'create_request_sheet.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  String _selectedBloodGroup = 'All';
  final List<String> _bloodGroups = ['All', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  int _getUrgencyPriority(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final hPadding = AppSpacing.horizontalPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Requests'),
        elevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: AppColors.divider.withOpacity(0.1),
            width: 1,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (String value) {
              setState(() {
                _selectedBloodGroup = value;
              });
            },
            itemBuilder: (BuildContext context) {
              return _bloodGroups.map((String group) {
                return PopupMenuItem<String>(
                  value: group,
                  child: Row(
                    children: [
                      if (_selectedBloodGroup == group)
                        const Icon(Icons.check, color: AppColors.primary, size: 18),
                      if (_selectedBloodGroup == group) const SizedBox(width: 8),
                      Text(group),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Process requests: map, filter completed, filter blood group, sort by urgency
          List<BloodRequest> requests = snapshot.data!.docs
              .map((doc) => BloodRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .where((request) => request.status != 'Completed')
              .toList();

          if (_selectedBloodGroup != 'All') {
            requests = requests.where((request) => request.bloodGroup == _selectedBloodGroup).toList();
          }

          // Sort by urgency (High -> Medium -> Low), then by date
          requests.sort((a, b) {
            int urgencyCompare = _getUrgencyPriority(b.urgency).compareTo(_getUrgencyPriority(a.urgency));
            if (urgencyCompare != 0) return urgencyCompare;
            return b.date.compareTo(a.date);
          });

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleIcon(icon: Icons.search_off, size: 80),
                  const SizedBox(height: 16),
                  Text(
                    _selectedBloodGroup == 'All' 
                      ? 'No Requests Yet' 
                      : 'No $_selectedBloodGroup Requests Found', 
                    style: const TextStyle(fontSize: 18, color: Colors.grey)
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 10),
            itemCount: requests.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildRequestCard(context, requests[index], authService);
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<UserModel?>(
        stream: authService.userDataStream,
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null || user.role != 'receiver') return const SizedBox.shrink();
          
          return FloatingActionButton(
            heroTag: 'requests_fab',
            onPressed: () => _showCreateRequestSheet(context),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }

  void _showCreateRequestSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const CreateRequestSheet(),
    );
  }

  Future<void> _acceptRequest(BuildContext context, BloodRequest request, UserModel currentUser) async {
    if (request.requesterId == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot accept your own request!")),
      );
      return;
    }

    try {
      final chatService = Provider.of<ChatService>(context, listen: false);

      // 1. Send automated donation request message to receiver
      String message = "${currentUser.name} wants to donate ${request.bloodGroup} blood for your request in ${request.city}.";
      await chatService.sendMessage(
        currentUser.uid, 
        request.requesterId, 
        message,
        roles: {currentUser.uid: 'donor', request.requesterId: 'receiver'},
        requestId: request.id,
        type: 'donation_request'
      );

      // 2. Create notification for receiver
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': request.requesterId,
        'title': 'New Donation Offer',
        'message': '${currentUser.name} wants to donate blood for your request.',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'donation_interest',
        'isRead': false,
        'data': {
          'donorId': currentUser.uid,
          'requestId': request.id,
        }
      });

      if (context.mounted) {
        // 3. Navigate to chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              receiverId: request.requesterId,
              receiverName: request.requesterName,
              myRole: 'donor',
              requestId: request.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.primary),
        );
      }
    }
  }

  Widget _buildRequestCard(BuildContext context, BloodRequest request, AuthService authService) {
    final theme = Theme.of(context);
    return StreamBuilder<UserModel?>(
      stream: authService.userDataStream,
      builder: (context, userSnapshot) {
        final currentUser = userSnapshot.data;
        if (currentUser == null) return const SizedBox.shrink();

        final bool isMyRequest = request.requesterId == currentUser.uid;
        final bool isDonor = currentUser.role == 'donor';
        final bool isCompleted = request.status == 'Completed';
        final bool inRecovery = currentUser.recoveryUntil != null && 
                               currentUser.recoveryUntil!.isAfter(DateTime.now());

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final Color groupColor = AppColors.getBloodGroupColor(request.bloodGroup);

        // Explicitly determine colors
        final Color bgColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
        final Color textColor = isDark ? Colors.white : Colors.black87;
        final Color subTextColor = isDark ? Colors.white70 : Colors.black54;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Blood Group indicator
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
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Main Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isMyRequest ? "Your Request" : request.requesterName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 15,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildUrgencyBadge(request.urgency),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${request.hospital}, ${request.city}',
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${request.units} Units Needed',
                          style: TextStyle(
                            color: groupColor.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isMyRequest) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              receiverId: request.requesterId,
                              receiverName: request.requesterName,
                              myRole: currentUser.role,
                              requestId: request.id,
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        foregroundColor: groupColor,
                      ),
                      child: const Text('Contact', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    if (isDonor && !isCompleted) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: inRecovery ? null : () => _acceptRequest(context, request, currentUser),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: inRecovery ? Colors.grey : groupColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          inRecovery ? 'In Recovery' : 'Accept',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ] else
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Your Request',
                      style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUrgencyBadge(String urgency) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        urgency,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
