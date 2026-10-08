import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'settings_screen.dart';
import 'card_detail_screen.dart';
import 'edit_screen.dart';
import '../models/app_user.dart';
import '../models/vibe_card.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/bottom_nav_widget.dart';
import '../widgets/like_button.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/share_bottom_sheet_widget.dart';
import '../widgets/aura_snack_bar.dart';
import '../widgets/vibe_card_canvas.dart';
import '../widgets/vibe_card_view.dart';
import '../theme/aura_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  static const String routeName = '/profile';

  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _selectedTab = 0;

  // the uid this screen is showing. the route can pass another user's id,
  // which is what happens when a name is tapped in the feed; with no
  // argument it falls back to the signed in user's own profile.
  String get _userId {
    final Object? argument = ModalRoute.of(context)?.settings.arguments;

    if (argument is String && argument.isNotEmpty) {
      return argument;
    }

    return _currentUid;
  }

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // settings, editing and the saved/liked tabs only make sense on your own
  bool get _isOwnProfile => _userId == _currentUid;

  // the profile document being shown, from whichever user it belongs to
  AppUser? get _shownProfile => _isOwnProfile
      ? ref.watch(currentUserProfileProvider).value
      : ref.watch(userProfileProvider(_userId)).value;

  static const _purple = Color(0xFF8B5CF6);

  // App Personalisation - current palette accent
  Color get _accent => AuraTheme.seed(ref.watch(auraPaletteProvider));
  static const _fieldBg = Color(0xFF1E1535);
  static const _pink = Color(0xFFFF2D78);
  static const _cardBg = Color(0xFF16102A);

  // guards against overlapping like writes from rapid taps
  bool _isLiking = false;

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  // like: atomic increment on the card plus the id on the user profile
  Future<void> _toggleLike(VibeCard card) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || _isLiking) return;

    _isLiking = true;

    final bool wasLiked = ref.read(likedPostIdsProvider).contains(card.postId);

    try {
      await ref
          .read(firestoreServiceProvider)
          .changeLikes(card.postId, !wasLiked);

      await ref
          .read(userServiceProvider)
          .toggleLikedPost(user.uid, card.postId, !wasLiked);
    } catch (error) {
      if (!mounted) return;

      _showAuraSnackBar(
        ref.read(firestoreServiceProvider).getErrorMessage(error),
      );
    } finally {
      _isLiking = false;
    }
  }

  // DELETE - removes the selected card from firestore
  Future<void> _deleteCard(VibeCard card) async {
    try {
      await ref.read(firestoreServiceProvider).deletePost(card.postId);

      if (!mounted) return;

      // the grid stream updates itself, so only the counters need refreshing
      ref.invalidate(userPostCountProvider(_userId));
      ref.invalidate(userLikeStatsProvider(_userId));

      _showAuraSnackBar('Vibe card deleted');
    } catch (error) {
      if (!mounted) return;

      _showAuraSnackBar(
        ref.read(firestoreServiceProvider).getErrorMessage(error),
      );
    }
  }

  // lets the user pick a new profile picture and stores it on their
  // user document as base64, the same approach used for vibe cards
  Future<void> _changeProfilePhoto(AppUser? profile) async {
    if (profile == null) {
      _showAuraSnackBar('Profile is still loading. Try again in a moment.');
      return;
    }

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: _purple,
                ),
                title: const Text(
                  'Take a photo',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: _pink),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      // a profile picture only ever renders small, so it is compressed
      // hard to keep the user document tiny
      final XFile? file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 70,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      await ref
          .read(userServiceProvider)
          .updatePhoto(profile.uid, base64Encode(bytes));

      if (!mounted) return;

      _showAuraSnackBar('Profile picture updated ✨');
    } catch (error) {
      if (!mounted) return;

      _showAuraSnackBar('Could not update your picture. Please try again.');
    }
  }

  // UPDATE on the users collection - lets the user change their identity.
  // opens a small validated form in a bottom sheet.
  void _showEditProfileSheet(AppUser? profile) {
    if (profile == null) {
      _showAuraSnackBar('Profile is still loading. Try again in a moment.');
      return;
    }

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController usernameController = TextEditingController(
      text: profile.username,
    );
    final TextEditingController bioController = TextEditingController(
      text: profile.bio,
    );
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16102A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: usernameController,
                      maxLength: 30,
                      keyboardType: TextInputType.text,
                      style: const TextStyle(color: Colors.white),
                      decoration: _editFieldDecoration('Username'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a username.';
                        }

                        if (value.trim().length < 3) {
                          return 'Username must be at least 3 characters.';
                        }

                        if (value.contains(' ')) {
                          return 'Username cannot contain spaces.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: bioController,
                      maxLength: 100,
                      maxLines: 2,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(color: Colors.white),
                      decoration: _editFieldDecoration('Bio'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a short bio.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) {
                                  return;
                                }

                                setSheetState(() {
                                  isSaving = true;
                                });

                                try {
                                  await ref
                                      .read(userServiceProvider)
                                      .updateProfile(
                                        uid: profile.uid,
                                        username: usernameController.text
                                            .trim(),
                                        bio: bioController.text.trim(),
                                      );

                                  if (!ctx.mounted) return;

                                  Navigator.of(ctx).pop();
                                  _showAuraSnackBar('Profile updated ✨');
                                } catch (error) {
                                  if (!ctx.mounted) return;

                                  setSheetState(() {
                                    isSaving = false;
                                  });

                                  _showAuraSnackBar(
                                    ref
                                        .read(userServiceProvider)
                                        .getErrorMessage(error),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save changes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // shared styling for the edit profile fields
  InputDecoration _editFieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
      counterStyle: const TextStyle(color: Colors.white38, fontSize: 11),
      filled: true,
      fillColor: _fieldBg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _purple, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _pink),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _pink),
      ),
      errorStyle: const TextStyle(color: _pink),
    );
  }

  void _showAuraSnackBar(String message) {
    showAuraSnackBar(
      context,
      message,
      backgroundColor: _fieldBg,
      iconColor: const Color(0xFFB28CFF),
      borderColor: _purple,
      textColor: Colors.white,
    );
  }

  // opens share popup for the profile share button
  void _showProfileShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ShareBottomSheetWidget(
          title: 'Share Profile',
          showMessage: _showAuraSnackBar,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: const BottomNavWidget(selectedIndex: 2),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTopBar(),
              _buildProfileHeader(),

              // Reduced this spacing so stats are closer to the profile section.
              const SizedBox(height: 6),

              _buildStatsRow(),
              const SizedBox(height: 14),
              _buildTabRow(),
              const SizedBox(height: 12),
              _buildGrid(),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 110),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // someone else's profile is pushed on top of the feed, so it
          // needs a way back
          if (!_isOwnProfile)
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white60,
                size: 22,
              ),
            ),
          const Spacer(),
          if (_isOwnProfile)
            GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, SettingsScreen.routeName),
              child: const Icon(
                Icons.settings_outlined,
                color: Colors.white60,
                size: 26,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final AppUser? profile = _shownProfile;

    // polaroid on the left, details on the right
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildPolaroid(profile),
          const SizedBox(width: 16),
          Expanded(child: _buildProfileInfo()),
        ],
      ),
    );
  }

  Widget _buildPolaroid(AppUser? profile) {
    const double polaroidAngle = -0.18;

    return SizedBox(
      width: 158,
      height: 225,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 54,
            top: 3,
            child: Transform.rotate(
              angle: polaroidAngle,
              child: Container(
                width: 82,
                height: 18,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.65),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 25,
            child: Transform.rotate(
              angle: polaroidAngle,
              child: Container(
                width: 115,
                height: 165,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.55),
                      blurRadius: 22,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 14,
                      offset: const Offset(5, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  // no rotation here, so the photo inherits the polaroid's
                  // tilt. rectangular so it fills the frame.
                  child: GestureDetector(
                    onTap: _isOwnProfile
                        ? () => _changeProfilePhoto(profile)
                        : null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ProfileAvatar(
                          photoBase64: profile?.photoBase64 ?? '',
                          username: profile?.username ?? '',
                          circle: false,
                          assetFallback: 'images/profile_image.png',
                        ),
                        // small hint that the picture can be changed
                        if (_isOwnProfile)
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.photo_camera_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 32,
            child: Transform.rotate(
              angle: polaroidAngle - 0.15,
              child: Icon(
                Icons.attach_file_rounded,
                color: Colors.grey.shade300,
                size: 28,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: -8,
            bottom: 30,
            child: Transform.rotate(
              angle: polaroidAngle,
              child: Icon(
                Icons.star_border_rounded,
                color: _purple,
                size: 58,
                shadows: [
                  Shadow(color: _purple.withValues(alpha: 0.9), blurRadius: 14),
                ],
              ),
            ),
          ),
          Positioned(
            right: 9,
            bottom: 45,
            child: Transform.rotate(
              angle: polaroidAngle,
              child: Icon(
                Icons.favorite_border_rounded,
                color: _purple,
                size: 34,
                shadows: [
                  Shadow(color: _purple.withValues(alpha: 0.8), blurRadius: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    // the real identity comes from this user's "users" document
    final AppUser? profile = _shownProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Flexible keeps the badge next to the name
            Flexible(
              child: Text(
                profile?.username ?? '...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'CaveatBrush',
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 7),
            const Icon(
              Icons.workspace_premium_outlined,
              color: _purple,
              size: 18,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          profile?.bio ?? 'farming aura ✨',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            // only the owner can edit; the share button stays for both, so
            // another user's profile can still be shared
            if (_isOwnProfile)
              GestureDetector(
                onTap: () {
                  _showEditProfileSheet(profile);
                },
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _fieldBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24),
                  ),
                  // mainAxisSize.min keeps the pill as narrow as its label
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.edit_outlined, color: Colors.white, size: 15),
                    ],
                  ),
                ),
              ),
            if (_isOwnProfile) const SizedBox(width: 8),
            GestureDetector(
              onTap: _showProfileShareSheet,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _fieldBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.send_outlined,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1035),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // AGGREGATION - count() of this user's cards, done on the server
          _statItem(
            Icons.style_outlined,
            _countLabel(),
            'Vibe Cards',
            Colors.white60,
          ),
          _vDivider(),
          // AGGREGATION - sum() of likes across this user's cards
          _statItem(Icons.favorite_rounded, _likesLabel(), 'Likes', _purple),
          _vDivider(),
          // AGGREGATION - average() likes per card
          _statItem(
            Icons.trending_up_rounded,
            _averageLabel(),
            'Avg / Card',
            Colors.white60,
          ),
        ],
      ),
    );
  }

  // reads the count aggregation, showing a dash while it loads
  String _countLabel() {
    final AsyncValue<int> count = ref.watch(userPostCountProvider(_userId));

    return count.when(
      loading: () => '-',
      error: (error, stackTrace) => '-',
      data: (value) => _formatCount(value),
    );
  }

  String _likesLabel() {
    final AsyncValue<Map<String, num>> stats = ref.watch(
      userLikeStatsProvider(_userId),
    );

    return stats.when(
      loading: () => '-',
      error: (error, stackTrace) => '-',
      data: (value) => _formatCount((value['total'] ?? 0).round()),
    );
  }

  String _averageLabel() {
    final AsyncValue<Map<String, num>> stats = ref.watch(
      userLikeStatsProvider(_userId),
    );

    return stats.when(
      loading: () => '-',
      error: (error, stackTrace) => '-',
      data: (value) => _formatCount((value['average'] ?? 0).round()),
    );
  }

  Widget _statItem(IconData icon, String count, String label, Color iconColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 17),
              const SizedBox(width: 5),
              Text(
                count,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() {
    return Container(width: 1, height: 34, color: Colors.white12);
  }

  Widget _buildTabRow() {
    // saved and liked are read from the signed in user's own profile
    // document, so they mean nothing when looking at someone else
    final tabs = _isOwnProfile
        ? [
            {'label': 'My Vibes', 'icon': Icons.grid_view_rounded},
            {'label': 'Saved Posts', 'icon': Icons.bookmark_outline_rounded},
            {'label': 'Liked Posts', 'icon': Icons.favorite_border_rounded},
          ]
        : [
            {'label': 'Their Vibes', 'icon': Icons.grid_view_rounded},
          ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(tabs.length, (i) {
          // another user's profile has one tab, so a Saved/Liked selection
          // carried over from your own profile must not leave it unhighlighted
          final bool selected = (_isOwnProfile ? _selectedTab : 0) == i;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = i;
                });
              },
              child: Container(
                margin: EdgeInsets.only(right: i < tabs.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? _accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: selected ? null : Border.all(color: Colors.white24),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!selected) ...[
                      Icon(
                        tabs[i]['icon'] as IconData,
                        color: Colors.white38,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        tabs[i]['label'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white54,
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGrid() {
    // tab 0 = my cards, tab 1 = saved cards, tab 2 = liked cards.
    // saved and liked read their id lists off the user profile and then
    // fetch those documents with a whereIn query.
    late final AsyncValue<List<VibeCard>> cards;
    late final String emptyMessage;

    // another user's profile only ever shows their own cards, so the saved
    // and liked branches are skipped even if a tab was selected before
    if (_isOwnProfile && _selectedTab == 1) {
      final List<String> savedIds = ref.watch(savedPostIdsProvider);
      cards = ref.watch(postsByIdsProvider(savedIds.join(',')));
      emptyMessage = 'No saved posts yet.\nTap the bookmark on any card.';
    } else if (_isOwnProfile && _selectedTab == 2) {
      final List<String> likedIds = ref.watch(likedPostIdsProvider);
      cards = ref.watch(postsByIdsProvider(likedIds.join(',')));
      emptyMessage = 'No liked posts yet.\nTap the heart on any card.';
    } else {
      // SELECT with a filter - only the cards belonging to this user
      cards = ref.watch(userPostsProvider(_userId));
      emptyMessage = 'No vibe cards yet.\nTap create to make your first one! ✨';
    }

    return cards.when(
      loading: () {
        return const SizedBox(
          height: 260,
          child: Center(child: CircularProgressIndicator(color: _purple)),
        );
      },
      error: (error, stackTrace) {
        return SizedBox(
          height: 260,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                ref.read(firestoreServiceProvider).getErrorMessage(error),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        );
      },
      data: (cards) {
        if (cards.isEmpty) {
          return SizedBox(
            height: 260,
            child: Center(
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: VibeCardCanvas.aspect,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) => _buildGridCard(cards[index]),
          ),
        );
      },
    );
  }

  Widget _buildGridCard(VibeCard card) {
    final bool liked = ref.watch(likedPostIdsProvider).contains(card.postId);

    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).pushNamed(CardDetailScreen.routeName, arguments: card.postId);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _cardBg,
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // the card art fills the tile
            Hero(
              tag: 'vibe-card-${card.postId}',
              child: VibeCardView(
                card: card,
                fit: BoxFit.cover,
                fallback: Container(
                  color: const Color(0xFF1A0A2E),
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.white24,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),

            // gradient keeps the overlay text readable on any photo
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 74,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),

            // stats sit on the art, so the tile stays image-led
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Row(
                children: [
                  LikeButton(
                    liked: liked,
                    likeCount: card.likes,
                    onTap: () => _toggleLike(card),
                    iconSize: 16,
                    fontSize: 11,
                    likedColor: _pink,
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(card.comments),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // owner menu, 44x44 tap area.
            // edit and delete belong to the card's owner, so it is left off
            // entirely when browsing someone else's profile
            if (_isOwnProfile)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: BoxDecoration(
                    // scrim so the icon stays visible on light photos
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    iconSize: 18,
                    // 18 icon + 13 padding each side = 44px tap target
                    padding: const EdgeInsets.all(13),
                    color: const Color(0xFF2D1B4E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.of(context).pushNamed(
                          EditScreen.routeName,
                          arguments: card.postId,
                        );
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(card);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: Colors.white70,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: _pink, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: _pink,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(VibeCard card) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1535),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Vibe Card?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will permanently remove this Aura Post.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteCard(card);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: _pink, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
