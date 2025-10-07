import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  AdminService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _admins =>
      _db.collection('admins');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<bool> isAdmin(String uid, {String? email}) async {
    // 1) Fast path: doc keyed by uid
    final byId = await _admins.doc(uid).get();
    if (byId.exists) return true;

    // 2) Fallback: a doc that has uid field
    final qByUid = await _admins.where('uid', isEqualTo: uid).limit(1).get();
    if (qByUid.docs.isNotEmpty) return true;

    // 3) Fallback: a doc that has email field
    if (email != null && email.isNotEmpty) {
      final qByEmail = await _admins
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (qByEmail.docs.isNotEmpty) return true;
    }

    return false;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllUsers() {
    return _users.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _users.doc(uid).update(data);
  }

  Future<void> deleteUser(String uid) async {
    await _users.doc(uid).delete();
  }

  Future<void> addAdmin({
    required String uid,
    required String email,
    String role = 'admin',
  }) async {
    // Store doc by uid for fast lookup
    await _admins.doc(uid).set({
      'uid': uid,
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
