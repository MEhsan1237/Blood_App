import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String bloodGroup;
  final DateTime dob;
  final double weight;
  final String gender;
  final bool hasDiabetes;
  final bool hasBloodPressure;
  final String otherDiseases;
  final bool agreeToDonate;
  final int loyaltyPoints;
  final int inAppDonations;
  final int externalDonations;
  final DateTime? lastDonationDate;
  final DateTime? recoveryUntil;
  final String role; // 'donor' or 'receiver'

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.bloodGroup,
    required this.dob,
    required this.weight,
    required this.gender,
    required this.hasDiabetes,
    required this.hasBloodPressure,
    this.otherDiseases = '',
    required this.agreeToDonate,
    this.loyaltyPoints = 0,
    this.inAppDonations = 0,
    this.externalDonations = 0,
    this.lastDonationDate,
    this.recoveryUntil,
    this.role = 'donor',
  });

  int get totalDonations => inAppDonations + externalDonations;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'city': city,
      'bloodGroup': bloodGroup,
      'dob': dob.toIso8601String(),
      'weight': weight,
      'gender': gender,
      'hasDiabetes': hasDiabetes,
      'hasBloodPressure': hasBloodPressure,
      'otherDiseases': otherDiseases,
      'agreeToDonate': agreeToDonate,
      'loyaltyPoints': loyaltyPoints,
      'inAppDonations': inAppDonations,
      'externalDonations': externalDonations,
      'lastDonationDate': lastDonationDate?.toIso8601String(),
      'recoveryUntil': recoveryUntil?.toIso8601String(),
      'role': role,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      city: map['city'] ?? '',
      bloodGroup: map['bloodGroup'] ?? '',
      dob: parseDate(map['dob']) ?? DateTime.now(),
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      gender: map['gender'] ?? '',
      hasDiabetes: map['hasDiabetes'] ?? false,
      hasBloodPressure: map['hasBloodPressure'] ?? false,
      otherDiseases: map['otherDiseases'] ?? '',
      agreeToDonate: map['agreeToDonate'] ?? false,
      loyaltyPoints: map['loyaltyPoints'] ?? 0,
      inAppDonations: map['inAppDonations'] ?? 0,
      externalDonations: map['externalDonations'] ?? 0,
      lastDonationDate: parseDate(map['lastDonationDate']),
      recoveryUntil: parseDate(map['recoveryUntil']),
      role: map['role'] ?? 'donor',
    );
  }
}
