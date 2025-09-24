import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  AdminService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _admins =>
      _db.collection('admins');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<bool> isAdmin(String uid) async {
    // Prefer doc keyed by uid if exists; else query by uid field
    final byId = await _admins.doc(uid).get();
    if (byId.exists) return true;
    final q = await _admins.where('uid', isEqualTo: uid).limit(1).get();
    return q.docs.isNotEmpty;
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
