import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vibe_card.dart';
import '../services/firestore_service.dart';

// gives every screen the same FirestoreService instance
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// the different ways the home feed can be queried
enum FeedMode {
  newest, // select all, sorted by date
  trending, // select all, sorted by likes
  byMeme, // one filter
  likeRange, // two filters on the same field
  memeAndLikes, // two filters on different fields
}

// holds which query the feed is currently using
class FeedFilter {
  final FeedMode mode;

  // the meme, which comes from the fixed library, so this list is short
  // and every option is guaranteed to match something
  final String meme;

  final int minLikes;
  final int maxLikes;

  const FeedFilter({
    this.mode = FeedMode.newest,
    this.meme = 'Cat Stare',
    this.minLikes = 0,
    this.maxLikes = 1000,
  });

  FeedFilter copyWith({
    FeedMode? mode,
    String? meme,
    int? minLikes,
    int? maxLikes,
  }) {
    return FeedFilter(
      mode: mode ?? this.mode,
      meme: meme ?? this.meme,
      minLikes: minLikes ?? this.minLikes,
      maxLikes: maxLikes ?? this.maxLikes,
    );
  }

  // true when the feed is showing something other than the default
  bool get isActive => mode != FeedMode.newest;

  // short description of the current filter, shown on the home screen
  String get label {
    switch (mode) {
      case FeedMode.newest:
        return 'Newest';
      case FeedMode.trending:
        return 'Trending';
      case FeedMode.byMeme:
        return '$meme meme';
      case FeedMode.likeRange:
        return '$minLikes-$maxLikes likes';
      case FeedMode.memeAndLikes:
        return '$meme · $minLikes-$maxLikes likes';
    }
  }
}

// lets the user change the feed query from the UI
class FeedFilterNotifier extends Notifier<FeedFilter> {
  @override
  FeedFilter build() {
    return const FeedFilter();
  }

  void setMode(FeedMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setMeme(String meme) {
    state = state.copyWith(meme: meme);
  }

  // picking a meme keeps any likes band that is already on, which is what
  // turns the two single-field queries into the different-fields one
  void setMemeFilter(String meme, {required bool withLikes}) {
    state = state.copyWith(
      meme: meme,
      mode: withLikes ? FeedMode.memeAndLikes : FeedMode.byMeme,
    );
  }

  // and the same the other way round: a likes band combines with whichever
  // meme is selected rather than replacing it
  void setLikeRange(int minLikes, int maxLikes, {required bool withMeme}) {
    state = state.copyWith(
      minLikes: minLikes,
      maxLikes: maxLikes,
      mode: withMeme ? FeedMode.memeAndLikes : FeedMode.likeRange,
    );
  }

  void reset() {
    state = const FeedFilter();
  }
}

final feedFilterProvider = NotifierProvider<FeedFilterNotifier, FeedFilter>(
  FeedFilterNotifier.new,
);

// SELECT ALL - every post in the collection, newest first
final allPostsProvider = StreamProvider<List<VibeCard>>((ref) {
  final FirestoreService service = ref.watch(firestoreServiceProvider);
  return service.selectAllPosts();
});

// the feed the home screen actually shows
// it swaps to a different firestore query when the filter changes
final feedPostsProvider = StreamProvider<List<VibeCard>>((ref) {
  final FirestoreService service = ref.watch(firestoreServiceProvider);
  final FeedFilter filter = ref.watch(feedFilterProvider);

  switch (filter.mode) {
    case FeedMode.newest:
      return service.selectSorted(sortByLikes: false);
    case FeedMode.trending:
      return service.selectSorted(sortByLikes: true);
    case FeedMode.byMeme:
      return service.selectByMeme(filter.meme);
    case FeedMode.likeRange:
      return service.selectByLikeRange(filter.minLikes, filter.maxLikes);
    case FeedMode.memeAndLikes:
      return service.selectByMemeAndLikes(
        filter.meme,
        filter.minLikes,
        filter.maxLikes,
      );
  }
});

// the Trending tab on the home screen - most liked cards first
final trendingPostsProvider = StreamProvider<List<VibeCard>>((ref) {
  final FirestoreService service = ref.watch(firestoreServiceProvider);
  return service.selectSorted(sortByLikes: true);
});

// cards matching a set of ids, used by the Saved and Liked profile tabs.
// the family key is a comma-joined string rather than a List, because Dart
// lists compare by identity: passing a new list on every rebuild would
// create a new provider (and a new firestore listener) each time.
final postsByIdsProvider = StreamProvider.family<List<VibeCard>, String>((
  ref,
  joinedIds,
) {
  final FirestoreService service = ref.watch(firestoreServiceProvider);

  final List<String> ids = joinedIds.isEmpty
      ? const <String>[]
      : joinedIds.split(',');

  return service.selectByIds(ids);
});

// SELECT ONE - used by the card detail screen.
// a stream rather than a future so an edit is reflected straight away
final singlePostProvider = StreamProvider.family<VibeCard?, String>((
  ref,
  postId,
) {
  final FirestoreService service = ref.watch(firestoreServiceProvider);
  return service.streamOnePost(postId);
});

// posts belonging to one user, used by the profile screen grid
final userPostsProvider = StreamProvider.family<List<VibeCard>, String>((
  ref,
  userId,
) {
  final FirestoreService service = ref.watch(firestoreServiceProvider);
  return service.selectPostsByUser(userId);
});

// AGGREGATION - how many cards this user has posted
final userPostCountProvider = FutureProvider.family<int, String>((ref, userId) {
  final FirestoreService service = ref.watch(firestoreServiceProvider);
  return service.countPostsByUser(userId);
});

// AGGREGATION - total and average likes for this user
final userLikeStatsProvider = FutureProvider.family<Map<String, num>, String>((
  ref,
  userId,
) {
  final FirestoreService service = ref.watch(firestoreServiceProvider);
  return service.likeStatsByUser(userId);
});
