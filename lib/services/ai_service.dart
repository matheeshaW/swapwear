import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AiService {
  AiService({FirebaseFunctions? functions, FirebaseFirestore? firestore})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;

  Future<List<String>> analyzeClothingAndUpdatePrefs({
    required String uid,
    required Uint8List imageBytes,
    String? filename,
  }) async {
    try {
      final callable = _functions.httpsCallable('analyzeClothing');
      final result = await callable.call({
        'filename': filename ?? 'image.jpg',
        'contentBase64': base64Encode(imageBytes),
      });
      final data = result.data as Map<dynamic, dynamic>;
      final tags = (data['tags'] as List).map((e) => e.toString()).toList();

      await _db.collection('users').doc(uid).update({
        'preferences': FieldValue.arrayUnion(tags),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return tags;
    } on FirebaseFunctionsException catch (e) {
      // Bubble meaningful error for UI
      throw Exception('Functions error: ${e.code} ${e.message ?? ''}'.trim());
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}
