import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<User?> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    return credential.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
