import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../models/badge_model.dart';
import '../../utils/constants.dart';
import '../../widgets/badge_widgets.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? myRole; // 'donor' or 'receiver'
  final String? requestId;

  const ChatScreen({
    super.key, 
    required this.receiverId, 
    required this.receiverName,
    this.myRole,
    this.requestId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage(ChatService chatService, String senderId) {
    if (_messageController.text.trim().isNotEmpty) {
      Map<String, String>? roles;
      if (widget.myRole != null) {
        roles = {
          senderId: widget.myRole!,
          widget.receiverId: widget.myRole == 'donor' ? 'receiver' : 'donor',
        };
      }

      chatService.sendMessage(
        senderId, 
        widget.receiverId, 
        _messageController.text.trim(),
        roles: roles,
        requestId: widget.requestId,
      );
      
      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _handleDonationAction(String donorId, ChatService chatService, String myId, String requestId, bool accept) async {
    if (!accept) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Donation request declined.")));
       return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Donation Request'),
        content: const Text('Are you sure you want to accept this donation? Once accepted, loyalty points will be added to the donor, and the request will be marked as completed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Accept', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Update Blood Request Status to Completed
      DocumentReference requestRef = FirebaseFirestore.instance.collection('requests').doc(requestId);
      batch.update(requestRef, {
        'status': 'Completed',
        'acceptedBy': donorId,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update Donor's stats (loyalty points, in-app donations, recovery period)
      DocumentReference donorRef = FirebaseFirestore.instance.collection('users').doc(donorId);
      batch.update(donorRef, {
        'loyaltyPoints': FieldValue.increment(100),
        'inAppDonations': FieldValue.increment(1),
        'recoveryUntil': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
        'lastDonationDate': DateTime.now().toIso8601String(),
      });

      // 3. Create notification for donor
      DocumentReference notifRef = FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': donorId,
        'title': 'Donation Accepted!',
        'message': '${widget.receiverName} has accepted your donation. +100 Loyalty Points added.',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'donation_confirmed',
        'isRead': false,
      });

      await batch.commit();

      // Send automated confirmation message in chat
      await chatService.sendMessage(
        myId, 
        donorId, 
        "I have accepted your donation request. Thank you for your support!",
        roles: {myId: 'receiver', donorId: 'donor'},
        requestId: requestId
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Donation Accepted! Request completed."), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  void _showDeleteDialog(ChatService chatService, String senderId, ChatMessage message) {
    if (message.senderId != senderId) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (message.id != null) {
                await chatService.deleteMessage(senderId, widget.receiverId, message.id!);
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final chatService = Provider.of<ChatService>(context, listen: false);

    return StreamBuilder<User?>(
      stream: authService.userStream,
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final myId = userSnapshot.data!.uid;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            shape: Border(
              bottom: BorderSide(
                color: AppColors.divider.withOpacity(0.1),
                width: 1,
              ),
            ),
            title: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.receiverId).snapshots(),
              builder: (context, snapshot) {
                String receiverName = widget.receiverName;
                BadgeTier? currentTier;

                if (snapshot.hasData && snapshot.data!.exists) {
                  final receiverData = UserModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);
                  receiverName = receiverData.name;
                  currentTier = BadgeTiers.getCurrentTier(
                    receiverData.totalDonations,
                    receiverData.loyaltyPoints,
                    receiverData.inAppDonations
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  receiverName,
                                  style: const TextStyle(fontSize: 18),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (currentTier != null) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _showBadgeDetails(context, currentTier!),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: currentTier.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        UserBadgeIcon(tier: currentTier, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          currentTier.name,
                                          style: TextStyle(
                                            color: currentTier.color,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (widget.myRole != null)
                            Text(
                              'Chatting as ${widget.myRole == 'donor' ? 'Donor' : 'Receiver'}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: chatService.getMessages(myId, widget.receiverId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data ?? [];

                    // Mark messages as read when they are received
                    if (messages.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        chatService.markMessagesAsRead(myId, widget.receiverId);
                      });
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == myId;

                        if (msg.type == 'donation_request') {
                          return _buildDonationRequestCard(msg, isMe, chatService, myId);
                        }

                        return _buildTextMessage(msg, isMe, chatService, myId);
                      },
                    );
                  },
                ),
              ),
              _buildMessageInput(chatService, myId),
            ],
          ),
        );
      },
    );
  }

  void _showBadgeDetails(BuildContext context, BadgeTier tier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserBadgeIcon(tier: tier, size: 80),
            const SizedBox(height: 16),
            Text(tier.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Earned by completing ${tier.minDonations} donations and reaching ${tier.minPoints} points.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextMessage(ChatMessage msg, bool isMe, ChatService chatService, String myId) {
    final bool isUnread = !isMe && !msg.isRead;

    return GestureDetector(
      onLongPress: () => _showDeleteDialog(chatService, myId, msg),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMe 
                ? AppColors.primary 
                : (isUnread ? AppColors.primary.withOpacity(0.08) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 2),
              bottomRight: Radius.circular(isMe ? 2 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
            border: isMe 
                ? null 
                : Border.all(
                    color: isUnread ? AppColors.primary.withOpacity(0.3) : AppColors.primary.withOpacity(0.1),
                    width: isUnread ? 1.5 : 1,
                  ),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                msg.message,
                style: TextStyle(
                  color: isMe ? Colors.white : (isUnread ? AppColors.primary : Colors.black87),
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isUnread)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonationRequestCard(ChatMessage msg, bool isMe, ChatService chatService, String myId) {
    final bool isUnread = !isMe && !msg.isRead;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.75,
        decoration: BoxDecoration(
          color: isUnread ? AppColors.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread ? AppColors.primary : AppColors.primary.withOpacity(0.3),
            width: isUnread ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.volunteer_activism, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isMe ? 'Donation Offer Sent' : 'New Donation Offer',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                if (isUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              msg.message,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            if (!isMe && msg.requestId != null) ...[
              const SizedBox(height: 16),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('requests').doc(msg.requestId).snapshots(),
                builder: (context, snapshot) {
                  bool isCompleted = false;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    isCompleted = data['status'] == 'Completed';
                  }

                  if (isCompleted) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Center(child: Text('ACCEPTED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleDonationAction(msg.senderId, chatService, myId, msg.requestId!, false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Decline', style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleDonationAction(msg.senderId, chatService, myId, msg.requestId!, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ] else if (isMe) ...[
              const SizedBox(height: 8),
              const Text(
                'Waiting for receiver to accept...',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ChatService chatService, String senderId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _sendMessage(chatService, senderId),
            ),
          ),
        ],
      ),
    );
  }
}
