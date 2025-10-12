import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  ProfileService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');

  Future<void> ensureUserProfile({required User user}) async {
    final docRef = _usersCol.doc(user.uid);
    final snap = await docRef.get();
    if (snap.exists) {
      // Update lastActiveAt even if profile exists
      await docRef.update({
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await docRef.set({
      'uid': user.uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'profilePic': user.photoURL,
      'role': 'customer', // Default role for new users
      'preferences': <String>[],
      'history': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    final doc = await _usersCol.doc(uid).get();
    return doc.data();
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    String? profilePic,
    List<String>? preferences,
  }) async {
    final update = <String, dynamic>{
      if (name != null) 'name': name,
      if (profilePic != null) 'profilePic': profilePic,
      if (preferences != null) 'preferences': preferences,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (update.isEmpty) return;
    await _usersCol.doc(uid).update(update);
  }

  Future<void> deactivateAccount({required String uid}) async {
    await _usersCol.doc(uid).delete();
  }

  // Update user activity timestamp
  Future<void> updateUserActivity(String uid) async {
    try {
      await _usersCol.doc(uid).update({
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user activity: $e');
    }
  }
}
