import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

// handles the "users" collection (the Users table from the proposal).
// every account gets one document keyed by its firebase uid, holding the
// profile identity plus personalisation settings like the theme palette.
class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _collection = 'users';

  CollectionReference get _users => _db.collection(_collection);

  // creates the user's profile document if it does not exist yet.
  // called after email/password signup (with the chosen username) and
  // after google / github sign-in (username taken from the account).
  Future<void> ensureProfile(User user, {String? username}) async {
    final DocumentReference doc = _users.doc(user.uid);
    final DocumentSnapshot snapshot = await doc.get();

    if (snapshot.exists) {
      return;
    }

    final String fallbackName =
        user.displayName ?? user.email?.split('@').first ?? 'aurafarmer';

    await doc.set({
      'username': username ?? fallbackName,
      'email': user.email ?? '',
      'bio': 'farming aura since ${DateTime.now().year} ✨',
      'isAuraPlus': false,
      'photoBase64': '',
      'notificationsEnabled': true,
      'privateAccount': false,
      'showAuraLevel': true,
      'savedPostIds': <String>[],
      'likedPostIds': <String>[],
      'themePalette': 'neonPurple',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // live stream of this user's profile, used by the profile screen and
  // by the theme system in main.dart
  Stream<AppUser?> streamProfile(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }

      return AppUser.fromFirestore(doc);
    });
  }

  // UPDATE on the users collection - edit profile form
  Future<void> updateProfile({
    required String uid,
    required String username,
    required String bio,
  }) async {
    await _users.doc(uid).update({'username': username, 'bio': bio});
  }

  // UPDATE - saves a new profile picture as base64
  Future<void> updatePhoto(String uid, String photoBase64) async {
    await _users.doc(uid).update({'photoBase64': photoBase64});
  }

  // UPDATE - persists one settings toggle (notifications, privacy, etc)
  Future<void> updateSetting(String uid, String field, bool value) async {
    await _users.doc(uid).update({field: value});
  }

  // adds or removes a card id from the user's saved list.
  // arrayUnion / arrayRemove are atomic, so two quick taps cannot
  // corrupt the list the way a read-modify-write would.
  Future<void> toggleSavedPost(String uid, String postId, bool save) async {
    await _users.doc(uid).update({
      'savedPostIds': save
          ? FieldValue.arrayUnion([postId])
          : FieldValue.arrayRemove([postId]),
    });
  }

  // same for likes, so the heart state survives a restart
  Future<void> toggleLikedPost(String uid, String postId, bool like) async {
    await _users.doc(uid).update({
      'likedPostIds': like
          ? FieldValue.arrayUnion([postId])
          : FieldValue.arrayRemove([postId]),
    });
  }

  // saves the picked theme so it follows the account across devices
  Future<void> setThemePalette(String uid, String palette) async {
    await _users.doc(uid).update({'themePalette': palette});
  }

  // converts firestore errors into simple messages
  String getErrorMessage(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'You do not have permission to do that.';
      } else if (error.code == 'unavailable') {
        return 'No internet connection. Please try again.';
      } else if (error.message != null) {
        return error.message!;
      }
    }

    return 'Something went wrong. Please try again.';
  }
}
