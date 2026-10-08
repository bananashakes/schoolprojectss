import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/user_service.dart';
import '../theme/aura_theme.dart';
import 'firebase_provider.dart';

// gives every screen the same UserService instance
final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

// live profile of whoever is logged in right now.
// switches automatically when the auth state changes.
final currentUserProfileProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  final User? user = authState.value;

  if (user == null) {
    return Stream.value(null);
  }

  return ref.watch(userServiceProvider).streamProfile(user.uid);
});

// ids of the cards the current user saved / liked, read straight from
// their profile document so every screen agrees on the state
// the profile behind a post's author id, so the feed and the card detail
// screen can show that person's real picture instead of a placeholder.
//
// .family caches one provider per uid, so the sample cards - which all
// share a single author - cost one firestore listener between them rather
// than one per card on screen.
final userProfileProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  if (uid.isEmpty) {
    return Stream<AppUser?>.value(null);
  }

  return ref.watch(userServiceProvider).streamProfile(uid);
});

final savedPostIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(currentUserProfileProvider).value?.savedPostIds ??
      const <String>[];
});

final likedPostIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(currentUserProfileProvider).value?.likedPostIds ??
      const <String>[];
});

// the palette the app should currently use.
// falls back to neon purple while logged out or still loading.
final auraPaletteProvider = Provider<AuraPalette>((ref) {
  final profile = ref.watch(currentUserProfileProvider);

  return AuraTheme.fromName(profile.value?.themePalette);
});
