import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/vibe_card.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';
import '../utils/meme_library.dart';
import '../widgets/aura_snack_bar.dart';
import '../widgets/bottom_nav_widget.dart';
import '../widgets/like_button.dart';
import '../widgets/offline_banner.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/share_bottom_sheet_widget.dart';
import '../widgets/vibe_card_canvas.dart';
import '../widgets/vibe_card_view.dart';
import '../theme/aura_theme.dart';
import 'card_detail_screen.dart';

// home feed screen for AuraFarm
// all vibe cards are now read live from cloud firestore
class HomeScreen extends ConsumerStatefulWidget {
  static const String routeName = '/home';

  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // fallback only; the live accent comes from the chosen Aura palette
  static const Color _purple = Color(0xFF8B5CF6);

  // App Personalisation - current palette accent
  Color get _accent => AuraTheme.seed(ref.watch(auraPaletteProvider));
  static const Color _textMuted = Color(0xFF8C8792);

  // change this file name if your profile image has another name
  static const String _profileImage = 'images/profile_avatar.png';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // accounts created before the users collection existed get their
    // profile document created here (ensureProfile does nothing if it
    // already exists)
    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      ref.read(userServiceProvider).ensureProfile(user).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // guards against overlapping like writes from rapid taps
  bool _isLiking = false;

  String _formatCount(int count) {
    if (count >= 1000) {
      double value = count / 1000;
      return '${value.toStringAsFixed(1)}k';
    }

    return count.toString();
  }

  // sends the like to firestore: the card's counter gets an atomic
  // increment, and the id is stored on the user's profile so the heart
  // stays filled after a restart
  Future<void> _toggleLike(VibeCard card) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || _isLiking) {
      return;
    }

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
      if (!mounted) {
        return;
      }

      _showHomeSnackBar(
        ref.read(firestoreServiceProvider).getErrorMessage(error),
      );
    } finally {
      _isLiking = false;
    }
  }

  // opens the reusable share popup
  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ShareBottomSheetWidget(showMessage: _showHomeSnackBar);
      },
    );
  }

  // shows message after user chooses share option
  void _showHomeSnackBar(String message) {
    showAuraSnackBar(
      context,
      message,
      backgroundColor: const Color(0xFF1B1224),
      iconColor: const Color(0xFFB28CFF),
      borderColor: _purple,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    // the feed rebuilds automatically whenever the filter changes
    final AsyncValue<List<VibeCard>> feed = ref.watch(feedPostsProvider);

    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(children: [_buildTopSection()]),
          ),
          const OfflineBanner(),
          _buildFilterBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFeedSection(feed),
                // trending tab runs the sort-by-likes firestore query
                _buildFeedSection(ref.watch(trendingPostsProvider)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavWidget(selectedIndex: 0),
    );
  }

  // top logo, profile icon and tabs
  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 15),
                child: Text(
                  'AuraFarm',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontFamily: 'CaveatBrush',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3.4,
                    height: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed('/profile');
                },
                child: Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2D7DFF),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2D7DFF).withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  // the picture the user set on their profile
                  child: ProfileAvatar(
                    photoBase64:
                        ref
                            .watch(currentUserProfileProvider)
                            .value
                            ?.photoBase64 ??
                        '',
                    username:
                        ref.watch(currentUserProfileProvider).value?.username ??
                        '',
                    size: 50,
                    assetFallback: _profileImage,
                  ),
                ),
              ),
            ],
          ),
          Transform.translate(
            offset: const Offset(-16, -12),
            child: _buildTabs(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      width: 205,
      height: 64,
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.only(top: 50, left: 0, right: 0),
        indicator: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: _textMuted,
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        tabs: const [
          Tab(text: 'For You'),
          Tab(text: 'Trending'),
        ],
      ),
    );
  }

  // one button that opens the filter sheet, plus a chip showing what the
  // feed is currently filtered to. each option in the sheet runs a
  // different firestore query.
  Widget _buildFilterBar() {
    final FeedFilter filter = ref.watch(feedFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          InkWell(
            onTap: _showFilterSheet,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: filter.isActive
                    ? _accent.withValues(alpha: 0.22)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: filter.isActive
                      ? _accent
                      : Colors.white.withValues(alpha: 0.14),
                  width: filter.isActive ? 1.4 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: filter.isActive ? Colors.white : _textMuted,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    filter.label,
                    style: TextStyle(
                      color: filter.isActive ? Colors.white : _textMuted,
                      fontSize: 12.5,
                      fontWeight: filter.isActive
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // only offered when there is something to clear
          if (filter.isActive)
            TextButton(
              onPressed: () {
                ref.read(feedFilterProvider.notifier).reset();
              },
              style: TextButton.styleFrom(
                foregroundColor: _textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Clear', style: TextStyle(fontSize: 12.5)),
            ),
        ],
      ),
    );
  }

  // the filter sheet. every row here swaps the feed to a different
  // firestore query rather than filtering the list in memory.
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101018),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        // watches inside the sheet so the ticks move as options are tapped
        return Consumer(
          builder: (context, sheetRef, child) {
            final FeedFilter filter = sheetRef.watch(feedFilterProvider);
            final FeedFilterNotifier notifier = sheetRef.read(
              feedFilterProvider.notifier,
            );

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _textMuted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Filter the feed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSheetHeading('Show'),
                    _buildSheetOption(
                      label: 'Newest first',
                      selected: filter.mode == FeedMode.newest,
                      onTap: () => notifier.setMode(FeedMode.newest),
                    ),
                    _buildSheetOption(
                      label: 'Most liked',
                      selected: filter.mode == FeedMode.trending,
                      onTap: () => notifier.setMode(FeedMode.trending),
                    ),
                    const SizedBox(height: 18),
                    // memes come from the fixed library, so every option
                    // here is guaranteed to match real cards.
                    // a meme and a likes band selected together run as one
                    // query across two different fields.
                    _buildSheetHeading('Meme'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: MemeLibrary.all.map((option) {
                        final bool onMeme =
                            filter.mode == FeedMode.byMeme ||
                            filter.mode == FeedMode.memeAndLikes;

                        return _buildSheetChip(
                          label: option.name,
                          selected: onMeme && filter.meme == option.name,
                          onTap: () => notifier.setMemeFilter(
                            option.name,
                            withLikes:
                                filter.mode == FeedMode.likeRange ||
                                filter.mode == FeedMode.memeAndLikes,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    _buildSheetHeading('Popularity'),
                    // the two bands must not share a boundary: selectByLikeRange
                    // is inclusive at both ends, so 0-1000 and 1000+ would both
                    // return a card with exactly 1000 likes
                    _buildSheetOption(
                      label: '0-999 likes',
                      selected:
                          (filter.mode == FeedMode.likeRange ||
                              filter.mode == FeedMode.memeAndLikes) &&
                          filter.maxLikes == 999,
                      onTap: () => notifier.setLikeRange(
                        0,
                        999,
                        withMeme:
                            filter.mode == FeedMode.byMeme ||
                            filter.mode == FeedMode.memeAndLikes,
                      ),
                    ),
                    _buildSheetOption(
                      label: '1,000+ likes',
                      selected:
                          (filter.mode == FeedMode.likeRange ||
                              filter.mode == FeedMode.memeAndLikes) &&
                          filter.maxLikes != 999,
                      onTap: () => notifier.setLikeRange(
                        1000,
                        1000000,
                        withMeme:
                            filter.mode == FeedMode.byMeme ||
                            filter.mode == FeedMode.memeAndLikes,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Done',
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

  Widget _buildSheetHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: _textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSheetOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: selected ? _accent : _textMuted.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _textMuted,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _accent : Colors.white.withValues(alpha: 0.14),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _textMuted,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // shows the loading, error and data states of the firestore stream
  Widget _buildFeedSection(AsyncValue<List<VibeCard>> feed) {
    return feed.when(
      loading: () {
        return const Center(child: CircularProgressIndicator(color: _purple));
      },
      error: (error, stackTrace) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.white38,
                  size: 44,
                ),
                const SizedBox(height: 14),
                Text(
                  ref.read(firestoreServiceProvider).getErrorMessage(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      data: (posts) {
        if (posts.isEmpty) {
          return const Center(
            child: Text(
              'No vibe cards yet.\nTap create to make your first one! ✨',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          );
        }

        return _buildFeed(posts);
      },
    );
  }

  // list of vibe cards in the home feed
  Widget _buildFeed(List<VibeCard> posts) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        12,
        6,
        12,
        MediaQuery.of(context).padding.bottom + 112,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return _buildImagePostCard(posts[index]);
      },
    );
  }

  // image card with like, comment and share bar
  Widget _buildImagePostCard(VibeCard card) {
    final bool liked = ref.watch(likedPostIdsProvider).contains(card.postId);

    return Container(
      margin: const EdgeInsets.only(bottom: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.28),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(
                context,
              ).pushNamed(CardDetailScreen.routeName, arguments: card.postId);
            },
            child: AspectRatio(
              aspectRatio: VibeCardCanvas.aspect,
              // Hero animates this image into the detail screen on tap
              child: Hero(
                tag: 'vibe-card-${card.postId}',
                child: VibeCardView(
                  card: card,
                  fallback: _buildMissingCardPlaceholder(card.vibe),
                ),
              ),
            ),
          ),
          _buildPostFooter(card: card, liked: liked),
        ],
      ),
    );
  }

  // shows the firestore data (user, vibe label, caption) under the image
  // single footer block: who posted it, what they said, and the actions.
  // the vibe label, song and meme already live on the card artwork, so
  // repeating them here only added noise.
  Widget _buildPostFooter({required VibeCard card, required bool liked}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      color: const Color(0xFF120D1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // author line - tapping it opens the profile
          GestureDetector(
            onTap: () {
              // the poster's profile, not the signed in user's
              Navigator.of(
                context,
              ).pushNamed('/profile', arguments: card.userId);
            },
            behavior: HitTestBehavior.opaque,
            child: Builder(
              builder: (context) {
                // the name stored on the post is a snapshot from when it was
                // written, so a later rename would leave the feed showing the
                // old one. the author's profile is already being read here for
                // their picture, so the live name comes from the same place.
                final String authorName =
                    ref
                        .watch(userProfileProvider(card.userId))
                        .value
                        ?.username ??
                    card.userName;

                return Row(
                  children: [
                    // author's picture, falling back to their initial
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _purple.withValues(alpha: 0.5),
                        ),
                      ),
                      child: ProfileAvatar(
                        photoBase64:
                            ref
                                .watch(userProfileProvider(card.userId))
                                .value
                                ?.photoBase64 ??
                            '',
                        username: authorName,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // caption
          if (card.caption.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                card.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],

          const SizedBox(height: 4),

          // actions - each one is a 44px tall touch target with 8px gaps
          Row(
            children: [
              SizedBox(
                height: 44,
                child: Center(
                  child: LikeButton(
                    liked: liked,
                    likeCount: card.likes,
                    onTap: () => _toggleLike(card),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildFooterAction(
                icon: Icons.chat_bubble_outline_rounded,
                label: _formatCount(card.comments),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    CardDetailScreen.routeName,
                    arguments: card.postId,
                  );
                },
              ),
              const Spacer(),
              _buildFooterAction(
                icon: Icons.send_outlined,
                label: 'Share',
                onTap: _showShareSheet,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 44x44 minimum tap area, per the mobile touch target guideline
  Widget _buildFooterAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        constraints: const BoxConstraints(minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 19),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingCardPlaceholder(String title) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16102A),
        border: Border.all(color: _purple.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_outlined, color: Colors.white54, size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add this card image in the images folder',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
