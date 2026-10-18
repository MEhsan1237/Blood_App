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

class RequestDetailsSheet extends StatelessWidget {
  final BloodRequest request;

  const RequestDetailsSheet({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color groupColor = AppColors.getBloodGroupColor(request.bloodGroup);

    return StreamBuilder<UserModel?>(
      stream: authService.userDataStream,
      builder: (context, snapshot) {
        final currentUser = snapshot.data;
        if (currentUser == null) return const SizedBox.shrink();

        final bool isMyRequest = request.requesterId == currentUser.uid;
        final bool isDonor = currentUser.role == 'donor';
        final bool isCompleted = request.status == 'Completed';
        final bool inRecovery = currentUser.recoveryUntil != null && 
                               currentUser.recoveryUntil!.isAfter(DateTime.now());

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: groupColor.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: groupColor.withOpacity(isDark ? 0.4 : 0.2),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        request.bloodGroup,
                        style: TextStyle(color: groupColor, fontWeight: FontWeight.bold, fontSize: 24),
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
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        _buildUrgencyBadge(request.urgency),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInfoRow(Icons.local_hospital_rounded, 'Hospital', request.hospital, groupColor),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.location_on_rounded, 'Location', '${request.city}, Pakistan', groupColor),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.water_drop_rounded, 'Requirement', '${request.units} Units Required', groupColor),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.calendar_month_rounded, 'Posted On', 
                  '${request.date.day}/${request.date.month}/${request.date.year}', groupColor),
              const SizedBox(height: 24),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                request.description.isEmpty ? 'No additional details provided.' : request.description,
                style: TextStyle(color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 32),
              if (!isMyRequest)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
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
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Contact'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: groupColor),
                          foregroundColor: groupColor,
                        ),
                      ),
                    ),
                    if (isDonor && !isCompleted) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: inRecovery ? null : () => _acceptRequest(context, request, currentUser),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: Text(inRecovery ? 'In Recovery' : 'Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: inRecovery ? Colors.grey : groupColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: groupColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'This is your blood request. You can manage it from "My Requests".',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: groupColor, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$urgency Urgency',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _acceptRequest(BuildContext context, BloodRequest request, UserModel currentUser) async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      
      // 1. Send automated donation request message
      String message = "${currentUser.name} wants to donate ${request.bloodGroup} blood for your request in ${request.city}.";
      await chatService.sendMessage(
        currentUser.uid, 
        request.requesterId, 
        message,
        roles: {currentUser.uid: 'donor', request.requesterId: 'receiver'},
        requestId: request.id,
        type: 'donation_request'
      );

      // 2. Create notification
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
        Navigator.pop(context); // Close bottom sheet
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
}
