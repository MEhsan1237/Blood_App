import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a single chat message between users.
class ChatMessage {
  final String? id; // For deletion
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final String type; // 'text' or 'donation_request'
  final String? requestId;
  final bool isRead;

  ChatMessage({
    this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.type = 'text',
    this.requestId,
    this.isRead = false,
  });

  /// Converts the message object to a Map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'type': type,
      'requestId': requestId,
      'isRead': isRead,
    };
  }

  /// Creates a message object from a Firestore Map.
  factory ChatMessage.fromMap(Map<String, dynamic> map, String docId) {
    return ChatMessage(
      id: docId,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      type: map['type'] ?? 'text',
      requestId: map['requestId'],
      isRead: map['isRead'] ?? true, // Default to true for old messages
    );
  }
}
