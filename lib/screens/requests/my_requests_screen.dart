import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/blood_request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/circle_icon.dart';
import 'edit_request_sheet.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  Future<void> _deleteRequest(BuildContext context, String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text('Are you sure you want to delete this blood request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('requests').doc(requestId).delete();
    }
  }

  Future<void> _markAsCompleted(BuildContext context, String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Completed'),
        content: const Text('Has this request been fulfilled? Marking it as completed will remove it from the active list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Complete', style: TextStyle(color: AppColors.success)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('requests').doc(requestId).update({
        'status': 'Completed',
      });
    }
  }

  void _editRequest(BuildContext context, BloodRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => EditRequestSheet(request: request),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final hPadding = AppSpacing.horizontalPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        elevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: AppColors.divider.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: authService.userDataStream,
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final userId = userSnapshot.data!.uid;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('requests')
                .where('requesterId', isEqualTo: userId)
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleIcon(icon: Icons.history, size: 80),
                      SizedBox(height: 16),
                      Text('You haven\'t posted any requests yet.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              final requests = snapshot.data!.docs
                  .map((doc) => BloodRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                  .toList();

              return ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 20),
                itemCount: requests.length,
                separatorBuilder: (context, index) => const SizedBox(height: 15),
                itemBuilder: (context, index) {
                  final theme = Theme.of(context);
                  final isDark = theme.brightness == Brightness.dark;
                  final request = requests[index];
                  final isCompleted = request.status == 'Completed';

                  // Explicitly determine colors
                  final Color bgColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
                  final Color textColor = isDark ? Colors.white : Colors.black87;
                  final Color subTextColor = isDark ? Colors.white70 : Colors.black54;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.05 : 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Blood Group: ${request.bloodGroup}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 17, 
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildStatusBadge(request.status),
                              ],
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert_rounded, color: subTextColor),
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _editRequest(context, request);
                                    break;
                                  case 'complete':
                                    _markAsCompleted(context, request.id);
                                    break;
                                  case 'delete':
                                    _deleteRequest(context, request.id);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                if (!isCompleted)
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                        SizedBox(width: 12),
                                        Text('Edit Details', style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                if (!isCompleted)
                                  const PopupMenuItem(
                                    value: 'complete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.success),
                                        SizedBox(width: 12),
                                        Text('Mark Completed', style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.primary),
                                      SizedBox(width: 12),
                                      Text('Delete Request', style: TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Hospital: ${request.hospital}', 
                          style: TextStyle(
                            fontSize: 14, 
                            color: subTextColor,
                          )
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Units: ${request.units}', 
                          style: TextStyle(
                            fontSize: 14,
                            color: subTextColor,
                          )
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Posted on: ${request.date.day}/${request.date.month}/${request.date.year}',
                          style: TextStyle(color: subTextColor.withOpacity(0.7), fontSize: 12),
                        ),
                        if (request.status == 'Accepted') ...[
                          const Divider(height: 24),
                          const Text(
                            'Status: Someone has accepted your request!',
                            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ]
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Accepted':
        color = AppColors.success;
        break;
      case 'Completed':
        color = Colors.blue;
        break;
      default:
        color = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
