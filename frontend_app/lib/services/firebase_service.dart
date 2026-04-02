import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _scamLogs =>
      _db.collection('scam_logs');

  Future<void> addScamLog({
    required String userId,
    required String title,
    required String phone,
    required String preview,
    required int risk,
    required bool danger,
    required String tactic,
  }) async {
    await _scamLogs.add({
      'userId':    userId,
      'title':     title,
      'phone':     phone,
      'preview':   preview,
      'risk':      risk,
      'danger':    danger,
      'tactic':    tactic,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> scamLogsStream(String userId) {
    return _scamLogs
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<int> scamCountStream(String userId) {
    return _scamLogs
        .where('userId', isEqualTo: userId)
        .where('danger', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
