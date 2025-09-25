import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref().child('profilePhotos').child('$uid.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Future<void> deleteProfilePhoto({required String uid}) async {
    final ref = _storage.ref().child('profilePhotos').child('$uid.jpg');
    try {
      await ref.delete();
    } catch (_) {}
  }
}
