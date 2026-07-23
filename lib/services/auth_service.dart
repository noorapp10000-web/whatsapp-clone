import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  static Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) return null;

    // Get FCM token
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (_) {}

    // Register on backend
    try {
      await ApiService.login(
        displayName: user.displayName,
        email: user.email,
        photoUrl: user.photoURL,
        fcmToken: fcmToken,
      );
    } catch (_) {}

    return user;
  }

  static Future<void> signOut() async {
    try {
      await ApiService.logout();
    } catch (_) {}
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
