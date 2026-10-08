import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

// handles all firebase authentication logic
class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // web client id for google sign in
  static const String googleWebClientId =
      '140916549752-83ol8hjhkcrubuob9e3r0pn34qs5blok.apps.googleusercontent.com';

  // creates a new email/password account
  Future<UserCredential> register(String email, String password) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // sends email verification after account is created
    await userCredential.user?.sendEmailVerification();

    return userCredential;
  }

  // logs in with email/password
  Future<UserCredential> login(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // google sign in
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn(
      clientId: googleWebClientId,
    ).signIn();

    // user closed the google pop up
    if (googleUser == null) {
      return null;
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  // github sign in
  Future<UserCredential?> signInWithGitHub() async {
    GithubAuthProvider githubProvider = GithubAuthProvider();

    // asks github for profile and email access
    githubProvider.addScope('read:user');
    githubProvider.addScope('user:email');

    if (kIsWeb) {
      return await _auth.signInWithPopup(githubProvider);
    }

    return await _auth.signInWithProvider(githubProvider);
  }

  // sends forgot password email
  Future<void> forgotPassword(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  // sends verification email to the current user
  Future<void> sendEmailVerification() async {
    User? user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently logged in.',
      );
    }

    await user.reload();
    user = _auth.currentUser;

    if (user != null && user.emailVerified == false) {
      await user.sendEmailVerification();
    }
  }

  // checks whether the current user's email is verified
  Future<bool> isEmailVerified() async {
    User? user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    await user.reload();
    user = _auth.currentUser;

    return user?.emailVerified ?? false;
  }

  // updates the current user's password
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    User? user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently logged in.',
      );
    }

    bool isPasswordUser = user.providerData.any(
      (info) => info.providerId == 'password',
    );

    if (!isPasswordUser) {
      throw FirebaseAuthException(
        code: 'not-password-user',
        message: 'Password can only be changed for email/password accounts.',
      );
    }

    String? email = user.email;

    if (email == null) {
      throw FirebaseAuthException(
        code: 'no-email',
        message: 'This account does not have an email address.',
      );
    }

    // firebase needs recent login before changing password
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  // gets the current logged in user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // gets the current user's email
  String getCurrentUserEmail() {
    return _auth.currentUser?.email ?? 'No email';
  }

  // checks if this account uses email/password login
  bool canChangePassword() {
    User? user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    return user.providerData.any((info) => info.providerId == 'password');
  }

  // shows which login method the user used
  List<String> getProviderNames() {
    User? user = _auth.currentUser;

    if (user == null) {
      return [];
    }

    return user.providerData.map((info) {
      if (info.providerId == 'password') {
        return 'Email/Password';
      } else if (info.providerId == 'google.com') {
        return 'Google';
      } else if (info.providerId == 'github.com') {
        return 'GitHub';
      } else {
        return info.providerId;
      }
    }).toList();
  }

  // refreshes the firebase user data
  Future<void> reloadUser() async {
    User? user = _auth.currentUser;

    if (user != null) {
      await user.reload();
    }
  }

  // logs out from google and firebase
  Future<void> logOut() async {
    try {
      await GoogleSignIn(clientId: googleWebClientId).signOut();
    } catch (e) {
      // even if google sign out fails, firebase should still logout
    }

    await _auth.signOut();
  }

  // converts firebase errors into simple messages
  String getErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      if (error.code == 'user-not-found') {
        return 'No account found with this email.';
      } else if (error.code == 'wrong-password') {
        return 'Incorrect password.';
      } else if (error.code == 'invalid-credential') {
        return 'Incorrect email or password.';
      } else if (error.code == 'invalid-email') {
        return 'Please enter a valid email.';
      } else if (error.code == 'email-already-in-use') {
        return 'This email is already used.';
      } else if (error.code == 'weak-password') {
        return 'Password is too weak.';
      } else if (error.code == 'requires-recent-login') {
        return 'Please log in again before changing your password.';
      } else if (error.code == 'not-password-user') {
        return 'Google/GitHub users cannot change password inside this app.';
      } else if (error.code == 'no-current-user') {
        return 'No user is currently logged in.';
      } else if (error.code == 'too-many-requests') {
        return 'Too many attempts. Please try again later.';
      } else if (error.message != null) {
        return error.message!;
      }
    }

    return 'Something went wrong. Please try again.';
  }
}
