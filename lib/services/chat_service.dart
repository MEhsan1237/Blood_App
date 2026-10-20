import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Sends a message and ensures the parent chat document exists with metadata.
  Future<void> sendMessage(
    String senderId, 
    String receiverId, 
    String message, {
    Map<String, String>? roles, 
    String? requestId,
    String type = 'text',
  }) async {
    final chatMessage = ChatMessage(
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      timestamp: DateTime.now(),
      type: type,
      requestId: requestId,
    );

    // Create a unique ID for the chat room (sorted to be deterministic)
    List<String> ids = [senderId, receiverId];
    ids.sort();
    String chatId = ids.join('_');

    // 1. Prepare Metadata for the parent document
    Map<String, dynamic> metadata = {
      'participants': ids,
      'lastMessage': type == 'donation_request' ? "Donation Request" : message,
      'lastTimestamp': FieldValue.serverTimestamp(),
    };

    // Store roles context if provided
    if (roles != null) {
      metadata['roles'] = roles;
    }
    
    // Store requestId if provided
    if (requestId != null) {
      metadata['requestId'] = requestId;
    }

    // 2. Update/Create the parent document in 'chats' collection
    await _db.collection('chats').doc(chatId).set(metadata, SetOptions(merge: true));

    // Update unread count for the receiver
    await _db.collection('chats').doc(chatId).update({
      'unreadCount_$receiverId': FieldValue.increment(1),
    });

    // 3. Add the actual message to the 'messages' sub-collection
    await _db.collection('chats').doc(chatId).collection('messages').add(chatMessage.toMap());
  }

  /// Marks all messages in a chat as read for the current user.
  Future<void> markMessagesAsRead(String myId, String otherUserId) async {
    List<String> ids = [myId, otherUserId];
    ids.sort();
    String chatId = ids.join('_');

    // Reset unread count in the chat metadata
    await _db.collection('chats').doc(chatId).update({
      'unreadCount_$myId': 0,
    });

    // Mark individual messages as read (optional, but good for UI highlighting)
    final unreadMessages = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: myId)
        .where('isRead', isEqualTo: false)
        .get();

    WriteBatch batch = _db.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Streams the total unread message count for a user across all chats.
  Stream<int> getTotalUnreadCount(String userId) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['unreadCount_$userId'] ?? 0) as int;
      }
      return total;
    });
  }

  /// Streams messages between two users in real-time.
  Stream<List<ChatMessage>> getMessages(String senderId, String receiverId) {
    List<String> ids = [senderId, receiverId];
    ids.sort();
    String chatId = ids.join('_');

    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return ChatMessage.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            }).toList());
  }

  /// Streams all chat rooms where the current user is a participant.
  Stream<QuerySnapshot> getChatRooms(String userId) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots();
  }

  /// Deletes a single message by its document ID.
  Future<void> deleteMessage(String senderId, String receiverId, String messageId) async {
    List<String> ids = [senderId, receiverId];
    ids.sort();
    String chatId = ids.join('_');
    await _db.collection('chats').doc(chatId).collection('messages').doc(messageId).delete();
  }

  /// Deletes an entire conversation history.
  Future<void> deleteChat(String chatId) async {
    final messages = await _db.collection('chats').doc(chatId).collection('messages').get();
    for (var doc in messages.docs) {
      await doc.reference.delete();
    }
    await _db.collection('chats').doc(chatId).delete();
  }
}
