import 'package:cloud_firestore/cloud_firestore.dart';

// model for one document in the "users" collection.
// this is the Users table from the Part 1 data dictionary, adapted for
// firestore: username, email, bio, aura+ flag, plus the chosen app theme.
class AppUser {
  final String uid;
  final String username;
  final String email;
  final String bio;
  final bool isAuraPlus;

  // the user's profile picture, stored as base64 text like the vibe cards.
  // firebase storage needs a paid plan, so the image is compressed small
  // and kept inside the document.
  final String photoBase64;

  // settings toggles, persisted so they survive restarts
  final bool notificationsEnabled;
  final bool privateAccount;
  final bool showAuraLevel;

  // ids of the cards this user saved / liked. kept on the user document
  // so both survive a restart and power the Saved and Liked tabs.
  final List<String> savedPostIds;
  final List<String> likedPostIds;

  // name of the AuraPalette this user picked (personalisation)
  final String themePalette;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.bio,
    required this.isAuraPlus,
    this.photoBase64 = '',
    this.notificationsEnabled = true,
    this.privateAccount = false,
    this.showAuraLevel = true,
    this.savedPostIds = const [],
    this.likedPostIds = const [],
    required this.themePalette,
    required this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return AppUser(
      uid: doc.id,
      username: data['username'] ?? 'aurafarmer',
      email: data['email'] ?? '',
      bio: data['bio'] ?? '',
      isAuraPlus: data['isAuraPlus'] ?? false,
      photoBase64: data['photoBase64'] ?? '',
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      privateAccount: data['privateAccount'] ?? false,
      showAuraLevel: data['showAuraLevel'] ?? true,
      savedPostIds: List<String>.from(data['savedPostIds'] ?? const []),
      likedPostIds: List<String>.from(data['likedPostIds'] ?? const []),
      themePalette: data['themePalette'] ?? 'neonPurple',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'email': email,
      'bio': bio,
      'isAuraPlus': isAuraPlus,
      'photoBase64': photoBase64,
      'notificationsEnabled': notificationsEnabled,
      'privateAccount': privateAccount,
      'showAuraLevel': showAuraLevel,
      'savedPostIds': savedPostIds,
      'likedPostIds': likedPostIds,
      'themePalette': themePalette,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
