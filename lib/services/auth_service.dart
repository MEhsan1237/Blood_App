import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of auth state changes
  Stream<User?> get userStream => _auth.authStateChanges();

  // Helper to get current firebase user
  User? get currentUser => _auth.currentUser;

  // LIVE STREAM of current user data from Firestore
  Stream<UserModel?> get userDataStream {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(null);
      }
      return _db.collection('users').doc(user.uid).snapshots().map((snapshot) {
        if (snapshot.exists) {
          return UserModel.fromMap(snapshot.data() as Map<String, dynamic>);
        }
        return null;
      });
    });
  }

  // Register user
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String city,
    required String bloodGroup,
    required DateTime dob,
    required double weight,
    required String gender,
    required bool hasDiabetes,
    required bool hasBloodPressure,
    required String otherDiseases,
    required bool agreeToDonate,
    String role = 'donor',
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        await user.sendEmailVerification();
        UserModel newUser = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          phone: phone,
          city: city,
          bloodGroup: bloodGroup,
          dob: dob,
          weight: weight,
          gender: gender,
          hasDiabetes: hasDiabetes,
          hasBloodPressure: hasBloodPressure,
          otherDiseases: otherDiseases,
          agreeToDonate: agreeToDonate,
          role: role,
        );

        await _db.collection('users').doc(user.uid).set(newUser.toMap());
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Login user
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Reset Password
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Get current user data (One-time fetch)
  Future<UserModel?> getUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    }
    return null;
  }
}
