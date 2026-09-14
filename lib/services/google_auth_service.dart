import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Runs the Google account picker and hands back a **Firebase** ID token,
/// not the raw Google OAuth one.
///
/// `GoogleSignInAuthentication.idToken` is a token minted by Google for the
/// app's OAuth client — its `aud` claim is that client ID. The backend
/// (POST /api/auth/sso/google) verifies the token with the Firebase Admin
/// SDK's `verifyIdToken()`, which only accepts tokens minted by Firebase
/// Auth itself (`aud` == the Firebase project). Sending the raw Google
/// token straight through — as this app used to — makes every Google
/// Sign-In attempt fail at the backend with "Invalid or expired Google
/// token". Exchanging it via `FirebaseAuth.signInWithCredential` and then
/// reading `user.getIdToken()` produces the token the backend actually
/// expects.
class GoogleAuthService {
  GoogleAuthService._();

  /// Returns the Firebase ID token, or `null` if the user cancelled the
  /// Google account picker. Throws if Google or Firebase sign-in fails.
  static Future<String?> signInAndGetFirebaseIdToken() async {
    final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

    // Sign out first so the account picker appears every time, instead of
    // silently reusing whichever Google account was last used.
    await googleSignIn.signOut();

    final account = await googleSignIn.signIn();
    if (account == null) return null; // user cancelled the picker

    final googleAuth = await account.authentication;
    if (googleAuth.idToken == null) {
      throw Exception('Could not get an ID token from Google');
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final firebaseIdToken = await userCredential.user?.getIdToken();
    if (firebaseIdToken == null) {
      throw Exception('Could not get a Firebase ID token');
    }
    return firebaseIdToken;
  }
}
