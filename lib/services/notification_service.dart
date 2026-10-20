import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Sends a notification to all users who match the requested blood group.
  Future<void> sendBloodRequestNotification({
    required String bloodGroup,
    required String city,
    required String requesterName,
    required String requesterId,
    required String requestId,
  }) async {
    try {
      // 1. Find matching donors who agreed to donate
      final querySnapshot = await _db
          .collection('users')
          .where('bloodGroup', isEqualTo: bloodGroup)
          .where('agreeToDonate', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = _db.batch();

      for (var doc in querySnapshot.docs) {
        // Don't send notification to the requester themselves
        if (doc.id == requesterId) continue;

        final notificationRef = _db.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': doc.id,
          'title': 'Urgent: $bloodGroup Needed',
          'message': '$requesterName needs $bloodGroup blood in $city. Tap to view details.',
          'type': 'blood_request',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'data': {
            'requestId': requestId,
            'bloodGroup': bloodGroup,
            'city': city,
          }
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error sending notifications: $e');
    }
  }

  /// Marks a notification as read
  Future<void> markAsRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({'isRead': true});
  }
}
