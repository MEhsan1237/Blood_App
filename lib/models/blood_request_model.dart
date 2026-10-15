import 'package:cloud_firestore/cloud_firestore.dart';

class BloodRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String bloodGroup;
  final String city;
  final String hospital;
  final int units;
  final DateTime date;
  final String description;
  final String urgency; // 'Low', 'Medium', 'High'
  final String status; // 'Open', 'Accepted', 'Completed'
  final String? acceptedBy;

  BloodRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.bloodGroup,
    required this.city,
    required this.hospital,
    required this.units,
    required this.date,
    required this.description,
    required this.urgency,
    this.status = 'Open',
    this.acceptedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'bloodGroup': bloodGroup,
      'city': city,
      'hospital': hospital,
      'units': units,
      'date': date.toIso8601String(),
      'description': description,
      'urgency': urgency,
      'status': status,
      'acceptedBy': acceptedBy,
    };
  }

  factory BloodRequest.fromMap(Map<String, dynamic> map, String documentId) {
    return BloodRequest(
      id: documentId,
      requesterId: map['requesterId'] ?? '',
      requesterName: map['requesterName'] ?? '',
      bloodGroup: map['bloodGroup'] ?? '',
      city: map['city'] ?? '',
      hospital: map['hospital'] ?? '',
      units: map['units'] ?? 0,
      date: DateTime.parse(map['date']),
      description: map['description'] ?? '',
      urgency: map['urgency'] ?? 'Low',
      status: map['status'] ?? 'Open',
      acceptedBy: map['acceptedBy'],
    );
  }
}
