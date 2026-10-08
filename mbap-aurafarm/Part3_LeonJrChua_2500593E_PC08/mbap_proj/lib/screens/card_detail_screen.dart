import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'edit_screen.dart';
import 'profile_screen.dart';
import '../models/vibe_card.dart';
import '../providers/music_provider.dart';
import '../providers/post_provider.dart';
import '../services/music_service.dart';
import '../services/preview_player_service.dart';
import '../providers/user_provider.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/bottom_nav_widget.dart';
import '../widgets/share_bottom_sheet_widget.dart';
import '../utils/sample_comments.dart';
import '../widgets/aura_snack_bar.dart';
import '../widgets/like_button.dart';
import '../widgets/vibe_card_canvas.dart';
import '../widgets/vibe_card_view.dart';
import '../theme/aura_theme.dart';

class CardDetailScreen extends ConsumerStatefulWidget {
  static const String routeName = '/card-detail';

  const CardDetailScreen({super.key});

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  // like and save state both live on the user's profile document, so the
  // detail screen just reads them instead of keeping its own copy
  int _likeDelta = 0;
  bool _isDeleting = false;

  // stops rapid taps from firing overlapping firestore writes, which
  // race each other and can leave the counter wrong
  bool _isLiking = false;

  // preview clip for this card's song, looked up on demand
  SongInfo _songInfo = SongInfo.empty;

  // which song the loaded clip belongs to, so editing the song swaps the
  // clip instead of leaving the old one attached to this card
  String _loadedSongKey = '';

  // only auto-play once per visit, never again on rebuild
  bool _hasAutoPlayed = false;
  bool _isPlaying = false;
  StreamSubscription<PlayerState>? _playerSub;

  // held directly because ref cannot be used inside dispose()
  PreviewPlayerService? _player;

  @override
  void initState() {
    super.initState();

    _player = ref.read(previewPlayerProvider);

    _playerSub = _player!.stateStream.listen((state) {
      if (!mounted) return;

      final bool finished = state.processingState == ProcessingState.completed;

      setState(() {
        _isPlaying = state.playing && !finished;
      });
    });
  }

  // WEB SERVICE - finds the clip for this card's song by name.
  // only the preview url is needed here; the card draws its own artwork.
  Future<void> _loadSongInfo(VibeCard card) async {
    if (card.songName.isEmpty) return;

    final String key = '${card.songName}|${card.songArtist}';

    // already have the clip for this exact song, nothing to do
    if (key == _loadedSongKey) return;

    // the edit screen sits on top of this one rather than replacing it, so
    // coming back from a song change lands here with the old clip still
    // loaded and playing. stop it and let the new song take over.
    final bool songChanged = _loadedSongKey.isNotEmpty;

    // set before the lookup so a rebuild mid-request cannot start a second
    _loadedSongKey = key;

    if (songChanged) {
      await _player?.stop();
      _hasAutoPlayed = false;
    }

    final SongInfo info = await ref
        .read(musicServiceProvider)
        .lookup(card.songName, card.songArtist);

    if (!mounted) return;

    setState(() {
      _songInfo = info;
    });

    if (info.previewUrl == null || _hasAutoPlayed) return;

    await _autoPlay(info.previewUrl!);
  }

  // starts the clip once the screen has settled, because opening a card
  // should feel like opening a post with sound.
  //
  // the page transition is still running when the lookup first returns, and
  // starting playback underneath it fails on android while the very same
  // code works on web. rather than guess one delay that suits both, this
  // makes a few attempts with a growing wait and stops at the first that
  // actually starts. giving up leaves the song chip working as normal.
  Future<void> _autoPlay(String url) async {
    const List<int> waitsMs = [350, 700, 1200];

    for (final int wait in waitsMs) {
      await Future<void>.delayed(Duration(milliseconds: wait));

      if (!mounted || _hasAutoPlayed) return;

      final PreviewPlayerService player = ref.read(previewPlayerProvider);

      // the user may have started something themselves while this waited,
      // and cutting them off would be worse than not autoplaying at all
      if (player.isPlaying) return;

      await player.play(url);

      if (player.lastError == null) {
        _hasAutoPlayed = true;
        return;
      }

      debugPrint('AuraFarm autoplay attempt failed after ${wait}ms, retrying');
    }

    debugPrint('AuraFarm autoplay gave up, the song chip still works');
  }

  Future<void> _togglePreview() async {
    final String? url = _songInfo.previewUrl;

    if (url == null) {
      _showAuraSnackBar('No preview available for this song.');
      return;
    }

    final player = ref.read(previewPlayerProvider);
    await player.play(url);

    if (!mounted) return;

    // playback silently failing is worse than saying so
    if (player.lastError != null) {
      _showAuraSnackBar('Could not play the preview on this device.');
    }
  }

  // marks the widget that gets rendered to PNG by the export feature
  final GlobalKey _cardBoundaryKey = GlobalKey();

  // the card currently on screen, kept so the share sheet can use it
  VibeCard? _loadedCard;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final GlobalKey<FormState> _commentFormKey = GlobalKey<FormState>();

  // comments the user adds during this session, shown above the samples
  final List<SampleComment> _ownComments = [];

  static const Color _surface = Color(0xFF120D18);
  static const Color _surfaceLight = Color(0xFF1B1224);
  static const Color _purple = Color(0xFF8B5CF6);

  // App Personalisation - live accent for the chosen Aura palette
  Color get _accent => AuraTheme.seed(ref.watch(auraPaletteProvider));
  static const Color _softPurple = Color(0xFFB28CFF);
  static const Color _pink = Color(0xFFFF4FA3);
  static const Color _textPrimary = Color(0xFFF7F0FF);
  static const Color _textMuted = Color(0xFF9A8FA5);
  static const Color _border = Color(0xFF2C1B3D);

  static const String _profileImage = 'images/profile_avatar.png';

  @override
  void dispose() {
    _playerSub?.cancel();
    _player?.stop();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  // like: atomic increment on the card, id stored on the user profile
  Future<void> _toggleLike(VibeCard card) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || _isLiking) return;

    _isLiking = true;

    final bool wasLiked = ref.read(likedPostIdsProvider).contains(card.postId);

    setState(() {
      _likeDelta += wasLiked ? -1 : 1;
    });

    try {
      await ref
          .read(firestoreServiceProvider)
          .changeLikes(card.postId, !wasLiked);

      await ref
          .read(userServiceProvider)
          .toggleLikedPost(user.uid, card.postId, !wasLiked);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _likeDelta += wasLiked ? 1 : -1;
      });

      _showAuraSnackBar(
        ref.read(firestoreServiceProvider).getErrorMessage(error),
      );
    } finally {
      _isLiking = false;
    }
  }

  // DELETE - removes this vibe card after the user confirms
  Future<void> _deleteCard(VibeCard card) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Delete this vibe card?',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'This cannot be undone. The card will be removed from your feed '
            'and your profile.',
            style: TextStyle(color: _textMuted, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: _textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFCF6679)),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await ref.read(firestoreServiceProvider).deletePost(card.postId);

      if (!mounted) return;

      // go back to the feed, the stream removes the card automatically
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
      });

      _showAuraSnackBar(
        ref.read(firestoreServiceProvider).getErrorMessage(error),
      );
    }
  }

  // owner-only menu with the edit and delete actions
  void _showOwnerMenu(VibeCard card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _textMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: _softPurple),
                title: const Text(
                  'Edit vibe card',
                  style: TextStyle(color: _textPrimary, fontSize: 15),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(
                    context,
                  ).pushNamed(EditScreen.routeName, arguments: card.postId);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFCF6679),
                ),
                title: const Text(
                  'Delete vibe card',
                  style: TextStyle(color: Color(0xFFCF6679), fontSize: 15),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _deleteCard(card);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ADDITIONAL FEATURE - saving a card writes its id to the user's
  // savedPostIds array, which powers the Saved tab on the profile
  Future<void> _toggleSave(VibeCard card) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final bool wasSaved = ref.read(savedPostIdsProvider).contains(card.postId);

    try {
      await ref
          .read(userServiceProvider)
          .toggleSavedPost(user.uid, card.postId, !wasSaved);

      if (!mounted) return;

      _showAuraSnackBar(
        wasSaved ? 'Removed from saved' : 'Saved to your collection',
      );
    } catch (error) {
      if (!mounted) return;

      _showAuraSnackBar(ref.read(userServiceProvider).getErrorMessage(error));
    }
  }

  void _submitComment() {
    // invalid input shows an inline error under the field
    if (!_commentFormKey.currentState!.validate()) {
      return;
    }

    final String commentText = _commentController.text.trim();

    setState(() {
      _ownComments.add(
        SampleComment(
          username: 'you',
          text: commentText,
          likes: '0',
          avatarPath: '',
        ),
      );
    });

    _commentController.clear();
    FocusScope.of(context).unfocus();
    _showAuraSnackBar('Comment added');
  }

  void _showAuraSnackBar(String message) {
    showAuraSnackBar(
      context,
      message,
      backgroundColor: _surfaceLight,
      iconColor: _softPurple,
      borderColor: _accent,
      textColor: _textPrimary,
    );
  }

  void _showExportSheet() {
    final VibeCard? card = _loadedCard;

    // proposal rule: only the owner may export their own vibe card as an
    // image, so the capture key is only passed for the owner's cards
    final bool isOwner =
        card != null && FirebaseAuth.instance.currentUser?.uid == card.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ShareBottomSheetWidget(
          showMessage: _showAuraSnackBar,
          captureKey: isOwner ? _cardBoundaryKey : null,
          fileName: 'aurafarm_${card?.postId ?? 'card'}.png',
          shareText: card == null
              ? 'Check out my vibe card on AuraFarm ✨'
              : '${card.caption} — ${card.vibe} vibe on AuraFarm ✨',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // the home feed passes the document id through the route arguments
    final Object? argument = ModalRoute.of(context)?.settings.arguments;
    final String postId = argument is String ? argument : '';

    // SELECT ONE - loads this single document from firestore
    final AsyncValue<VibeCard?> postAsync = ref.watch(
      singlePostProvider(postId),
    );

    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(children: [_buildTopSection()]),
          ),
          Expanded(
            child: postAsync.when(
              loading: () {
                return Center(child: CircularProgressIndicator(color: _accent));
              },
              error: (error, stackTrace) {
                return _buildMessage(
                  ref.read(firestoreServiceProvider).getErrorMessage(error),
                );
              },
              data: (card) {
                if (card == null) {
                  return _buildMessage('This vibe card no longer exists.');
                }

                return _buildCardBody(card);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavWidget(selectedIndex: -1),
    );
  }

  // simple centered message used for the error and missing states
  Widget _buildMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _textMuted, size: 44),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // the real content once the document has loaded
  Widget _buildCardBody(VibeCard card) {
    // remembered so the export sheet in the app bar can reach the card
    _loadedCard = card;

    // fetch the preview clip after this frame, never during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSongInfo(card);
    });

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).padding.bottom + 116,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVibeCardImage(card),
          const SizedBox(height: 8),
          _buildEngagementBar(card),
          const SizedBox(height: 10),
          _buildPostInfoBox(card),
          const SizedBox(height: 14),
          _buildCommentInput(),
          const SizedBox(height: 20),
          _buildCommentsHeader(),
          const SizedBox(height: 16),
          _buildCommentsList(card),
        ],
      ),
    );
  }

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const Expanded(
            child: Text(
              'AuraFarm',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontFamily: 'CaveatBrush',
                fontWeight: FontWeight.w700,
                letterSpacing: 3.4,
                height: 1.0,
              ),
            ),
          ),
          IconButton(
            onPressed: _showExportSheet,
            icon: const Icon(
              Icons.ios_share_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVibeCardImage(VibeCard card) {
    // RepaintBoundary lets the export feature render exactly this widget
    // (photo, border and glow included) into the shared PNG
    return RepaintBoundary(
      key: _cardBoundaryKey,
      child: _buildVibeCardImageInner(card),
    );
  }

  Widget _buildVibeCardImageInner(VibeCard card) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _accent.withValues(alpha: 0.45), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.20),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: AspectRatio(
          aspectRatio: VibeCardCanvas.aspect,
          child: Hero(
            tag: 'vibe-card-${card.postId}',
            child: VibeCardView(
              card: card,
              fallback: Container(
                color: _surface,
                child: const Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: _textMuted,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEngagementBar(VibeCard card) {
    final bool isLiked = ref.watch(likedPostIdsProvider).contains(card.postId);
    final bool isSaved = ref.watch(savedPostIdsProvider).contains(card.postId);

    return Container(
      // 48 gives the row inside it a full 44px tap band
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          LikeButton(
            liked: isLiked,
            likeCount: card.likes + _likeDelta,
            onTap: () => _toggleLike(card),
            iconSize: 27,
            fontSize: 14,
            likedColor: _pink,
            idleColor: Colors.white70,
          ),
          const SizedBox(width: 26),
          GestureDetector(
            onTap: () {
              _commentFocusNode.requestFocus();
            },
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white60,
                  size: 25,
                ),
                const SizedBox(width: 6),
                Text(
                  '${card.comments + _ownComments.length}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 26),
          GestureDetector(
            onTap: _showExportSheet,
            child: const Row(
              children: [
                Icon(Icons.near_me_outlined, color: Colors.white60, size: 27),
                SizedBox(width: 6),
                Text(
                  'Share',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _toggleSave(card),
            child: Row(
              children: [
                Icon(
                  isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: isSaved ? _softPurple : Colors.white60,
                  size: 27,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostInfoBox(VibeCard card) {
    // only the person who created the card may edit or delete it
    final bool isOwner = FirebaseAuth.instance.currentUser?.uid == card.userId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  // the poster's profile, not the signed in user's
                  Navigator.of(
                    context,
                  ).pushNamed(ProfileScreen.routeName, arguments: card.userId);
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAvatar(42, card),
                    const SizedBox(width: 9),
                    Text(
                      // live name from the author's profile; the one stored
                      // on the post is a snapshot from when it was written
                      ref
                              .watch(userProfileProvider(card.userId))
                              .value
                              ?.username ??
                          card.userName,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.verified_rounded,
                      color: _softPurple,
                      size: 18,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // the edit / delete menu only appears on your own cards
              if (isOwner)
                GestureDetector(
                  onTap: _isDeleting
                      ? null
                      : () {
                          _showOwnerMenu(card);
                        },
                  behavior: HitTestBehavior.opaque,
                  child: _isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _softPurple,
                          ),
                        )
                      : const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white60,
                          size: 25,
                        ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            card.caption,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildTag('#${card.displayVibe.replaceAll(' ', '')}'),
              if (card.songName.isNotEmpty) _buildSongTag(card),
              if (card.memeName.isNotEmpty)
                _buildTag('${card.memeEmoji} ${card.memeName}'),
            ],
          ),
        ],
      ),
    );
  }

  // the whole chip is the play control, not just the icon
  Widget _buildSongTag(VibeCard card) {
    final bool hasPreview = _songInfo.previewUrl != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasPreview ? _togglePreview : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _isPlaying ? _accent.withValues(alpha: 0.22) : _surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasPreview
                  ? _accent.withValues(alpha: _isPlaying ? 0.9 : 0.6)
                  : _accent.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasPreview
                    ? (_isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded)
                    : Icons.music_note_rounded,
                color: hasPreview ? _softPurple : _textMuted,
                size: 17,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  card.songName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasPreview ? _textPrimary : _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (hasPreview) ...[
                const SizedBox(width: 7),
                Text(
                  _isPlaying ? 'Tap to stop' : 'Tap to play',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _purple.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // the comment box is a real Form so empty or too-long input shows an
  // inline error instead of failing silently
  Widget _buildCommentInput() {
    return Form(
      key: _commentFormKey,
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 5),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _accent.withValues(alpha: 0.70),
            width: 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                maxLength: 150,
                keyboardType: TextInputType.text,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: _softPurple,
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  border: InputBorder.none,
                  // the counter would break the compact layout
                  counterText: '',
                  errorStyle: TextStyle(color: Color(0xFFFF6E8A), fontSize: 11),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please write a comment first.';
                  }

                  if (value.trim().length < 2) {
                    return 'Comment is too short.';
                  }

                  return null;
                },
                onFieldSubmitted: (value) {
                  _submitComment();
                },
              ),
            ),
            GestureDetector(
              onTap: _submitComment,
              behavior: HitTestBehavior.opaque,
              // the circle stays 37px visually, but the tap area is 44px
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Container(
                    width: 37,
                    height: 37,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accent,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsHeader() {
    return Row(
      children: const [
        Text(
          'Comments',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        Spacer(),
        Text(
          'Most recent',
          style: TextStyle(
            color: _softPurple,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 3),
        Icon(Icons.keyboard_arrow_down_rounded, color: _softPurple, size: 22),
      ],
    );
  }

  Widget _buildCommentsList(VibeCard card) {
    // sample comments belong to the seeded demo cards only. a card the
    // user just made has none, so it shows an empty state rather than
    // other people's comments.
    final List<SampleComment> comments = [
      ..._ownComments,
      if (card.comments > 0) ...SampleComments.all,
    ];

    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: _textMuted.withValues(alpha: 0.6),
                size: 30,
              ),
              const SizedBox(height: 10),
              const Text(
                'No comments yet',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Be the first to say something',
                style: TextStyle(color: _textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: comments.map(_buildCommentTile).toList());
  }

  Widget _buildCommentTile(SampleComment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommenterAvatar(comment, 40),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.username,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(
                Icons.favorite_border_rounded,
                color: _softPurple,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                comment.likes,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // uses the commenter's avatar image when one exists, otherwise a
  // coloured initial so every commenter still looks distinct
  Widget _buildCommenterAvatar(SampleComment comment, double size) {
    final List<Color> palette = [
      const Color(0xFF8B5CF6),
      const Color(0xFFFF4FA3),
      const Color(0xFF03DAC6),
      const Color(0xFFFFAA00),
      const Color(0xFF2D7DFF),
    ];

    final Color tint =
        palette[SampleComments.colorSeed(comment.username) % palette.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withValues(alpha: 0.22),
        border: Border.all(color: tint.withValues(alpha: 0.7), width: 1.5),
      ),
      child: ClipOval(
        child: comment.avatarPath.isEmpty
            ? _buildInitial(comment.username, tint)
            : Image.asset(
                comment.avatarPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildInitial(comment.username, tint);
                },
              ),
      ),
    );
  }

  Widget _buildInitial(String username, Color tint) {
    return Center(
      child: Text(
        username.isEmpty ? '?' : username[0].toUpperCase(),
        style: TextStyle(
          color: tint,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // the picture of whoever posted this card
  Widget _buildAvatar(double size, VibeCard card) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _purple.withValues(alpha: 0.65), width: 1.5),
      ),
      child: ProfileAvatar(
        photoBase64:
            ref.watch(userProfileProvider(card.userId)).value?.photoBase64 ??
            '',
        username:
            ref.watch(userProfileProvider(card.userId)).value?.username ??
            card.userName,
        size: size - 4,
        assetFallback: _profileImage,
      ),
    );
  }
}
