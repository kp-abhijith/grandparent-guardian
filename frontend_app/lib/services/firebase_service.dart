import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _scamLogs =>
      _db.collection('scam_logs');

  Future<String> addScamLog({
    required String userId,
    required String title,
    required String phone,
    required String preview,
    required int risk,
    required bool danger,
    required String tactic,
  }) async {
    final docRef = await _scamLogs.add({
      'userId':    userId,
      'title':     title,
      'phone':     phone,
      'preview':   preview,
      'risk':      risk,
      'danger':    danger,
      'tactic':    tactic,
      'isBlocked': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> scamLogsStream(String userId) {
    return _scamLogs
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> blockCaller(String documentId) async {
    await _scamLogs.doc(documentId).update({'isBlocked': true});
  }

  Stream<int> scamDetectedCountStream(String userId) {
    return _scamLogs
        .where('userId', isEqualTo: userId)
        .where('danger', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> scamBlockedCountStream(String userId) {
    return _scamLogs
        .where('userId', isEqualTo: userId)
        .where('isBlocked', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
