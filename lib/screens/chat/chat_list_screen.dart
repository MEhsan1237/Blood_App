import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../utils/constants.dart';
import '../../models/user_model.dart';
import '../../models/badge_model.dart';
import '../../widgets/badge_widgets.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final chatService = Provider.of<ChatService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: theme.textTheme.titleLarge?.color),
              decoration: const InputDecoration(
                hintText: 'Search by name...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            )
          : Text(
              'Messages',
              style: TextStyle(
                color: theme.textTheme.titleLarge?.color,
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: theme.iconTheme.color),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
        shape: Border(
          bottom: BorderSide(
            color: AppColors.divider.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      body: StreamBuilder<User?>(
        stream: authService.userStream,
        builder: (context, authSnapshot) {
          final user = authSnapshot.data ?? FirebaseAuth.instance.currentUser;
          if (user == null) {
            return Center(child: Text('Please login to view messages', style: TextStyle(color: theme.disabledColor)));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: chatService.getChatRooms(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return _buildEmptyState(context);

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final chatRoom = docs[index];
                  final data = chatRoom.data() as Map<String, dynamic>;
                  final participants = List<String>.from(data['participants'] ?? []);
                  String otherUserId = participants.firstWhere((id) => id != user.uid, orElse: () => '');

                  if (otherUserId.isEmpty) return const SizedBox.shrink();

                  return _ChatListItem(
                    chatId: chatRoom.id,
                    otherUserId: otherUserId,
                    data: data,
                    myId: user.uid,
                    chatService: chatService,
                    searchQuery: _searchQuery,
                  );
                },
              );
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
          Icon(Icons.chat_bubble_outline, size: 80, color: theme.disabledColor.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No conversations yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ChatListItem extends StatelessWidget {
  final String chatId;
  final String otherUserId;
  final Map<String, dynamic> data;
  final String myId;
  final ChatService chatService;
  final String searchQuery;

  const _ChatListItem({
    required this.chatId,
    required this.otherUserId,
    required this.data,
    required this.myId,
    required this.chatService,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox.shrink();

        final userData = UserModel.fromMap(userSnapshot.data!.data() as Map<String, dynamic>);
        final String name = userData.name;

        // Search Filter
        if (searchQuery.isNotEmpty && !name.toLowerCase().contains(searchQuery)) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final lastMessage = data['lastMessage'] ?? 'No messages yet';
        final lastTimestamp = data['lastTimestamp'] as Timestamp?;
        final roles = data['roles'] as Map<String, dynamic>?;
        final myRoleInChat = roles?[myId];
        final unreadCount = data['unreadCount_$myId'] ?? 0;
        
        final otherUserTier = BadgeTiers.getCurrentTier(
          userData.totalDonations,
          userData.loyaltyPoints,
          userData.inAppDonations,
        );

        return Dismissible(
          key: Key(chatId),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => chatService.deleteChat(chatId),
          background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(receiverId: otherUserId, receiverName: name, myRole: myRoleInChat, requestId: data['requestId']))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: unreadCount > 0 ? AppColors.primary.withOpacity(0.06) : Colors.transparent,
                border: unreadCount > 0 ? const Border(left: BorderSide(color: AppColors.primary, width: 4)) : null,
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      if (otherUserTier != null) UserBadgeIcon(tier: otherUserTier, size: 20),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                            if (lastTimestamp != null) Text(_formatTimestamp(lastTimestamp), style: TextStyle(fontSize: 12, color: theme.disabledColor)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unreadCount > 0 ? theme.textTheme.bodyMedium?.color : theme.disabledColor,
                                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                                child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    if (now.day == date.day && now.month == date.month && now.year == date.year) return DateFormat.jm().format(date);
    return DateFormat.MMMd().format(date);
  }
}
