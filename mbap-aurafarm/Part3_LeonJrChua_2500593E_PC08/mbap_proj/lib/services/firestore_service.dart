import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vibe_card.dart';

// handles all cloud firestore database logic for vibe cards
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // name of the collection used for the CRUD set
  static const String _collection = 'posts';

  CollectionReference get _posts => _db.collection(_collection);

  // ---------------------------------------------------------------
  // BASIC CRUD
  // ---------------------------------------------------------------

  // CREATE - inserts a new vibe card and returns the new document id
  Future<String> insertPost(VibeCard card) async {
    final DocumentReference doc = await _posts.add(card.toFirestore());
    return doc.id;
  }

  // READ (select all) - live stream of every post, newest first
  Stream<List<VibeCard>> selectAllPosts() {
    return _posts.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => VibeCard.fromFirestore(doc)).toList();
    });
  }

  // READ (select one) - live, so the detail screen picks up an edit made
  // elsewhere straight away
  Stream<VibeCard?> streamOnePost(String postId) {
    return _posts.doc(postId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }

      return VibeCard.fromFirestore(doc);
    });
  }

  // READ (select one) - one-shot fetch, used when loading a card into the
  // editor where a live stream would fight the user's own edits
  Future<VibeCard?> selectOnePost(String postId) async {
    final DocumentSnapshot doc = await _posts.doc(postId).get();

    if (!doc.exists) {
      return null;
    }

    return VibeCard.fromFirestore(doc);
  }

  // UPDATE - only the fields the edit screen can change. writing the whole
  // document would clobber the likes counter with a stale value.
  Future<void> updatePost(VibeCard card) async {
    await _posts.doc(card.postId).update({
      'caption': card.caption,
      'vibe': card.vibe,
      // the wording printed on the card, cleared when the user picks a
      // vibe by hand so the chosen category shows instead
      'vibeLabel': card.vibeLabel,
      'vibeLabelOptions': card.vibeLabelOptions,
      'songOptions': card.songOptions,
      'memeOptions': card.memeOptions,
      'songName': card.songName,
      'songArtist': card.songArtist,
      // changing the song changes its artwork, and the card is drawn from
      // these fields now, so this has to travel with them
      'albumArtUrl': card.albumArtUrl,
      'memeName': card.memeName,
      'memeEmoji': card.memeEmoji,
      'isPublic': card.isPublic,
    });
  }

  // DELETE - removes a post from the collection
  Future<void> deletePost(String postId) async {
    await _posts.doc(postId).delete();
  }

  // ---------------------------------------------------------------
  // ADVANCED QUERIES
  // ---------------------------------------------------------------

  // 1. select with ONE filter criteria (not the identifier)
  // e.g. show only the cards using the "Rage" meme.
  // one where clause, so firestore serves it from the automatic index.
  Stream<List<VibeCard>> selectByMeme(String memeName) {
    return _posts.where('memeName', isEqualTo: memeName).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => VibeCard.fromFirestore(doc)).toList();
    });
  }

  // 2. select with MULTIPLE filter criteria on the SAME field
  // e.g. only cards whose likes are between a min and a max
  Stream<List<VibeCard>> selectByLikeRange(int minLikes, int maxLikes) {
    return _posts
        .where('likes', isGreaterThanOrEqualTo: minLikes)
        .where('likes', isLessThanOrEqualTo: maxLikes)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => VibeCard.fromFirestore(doc))
              .toList();
        });
  }

  // 3. select with MULTIPLE filter criteria on DIFFERENT fields
  // e.g. cards using one meme that also sit inside a likes band.
  // an equality on one field plus a range on another needs a composite
  // index (memeName + likes), unlike the single-field queries above.
  Stream<List<VibeCard>> selectByMemeAndLikes(
    String memeName,
    int minLikes,
    int maxLikes,
  ) {
    return _posts
        .where('memeName', isEqualTo: memeName)
        .where('likes', isGreaterThanOrEqualTo: minLikes)
        .where('likes', isLessThanOrEqualTo: maxLikes)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => VibeCard.fromFirestore(doc))
              .toList();
        });
  }

  // 4. select with a SORT ORDER
  // sortByLikes = true  -> most liked first (trending)
  // sortByLikes = false -> newest first
  Stream<List<VibeCard>> selectSorted({required bool sortByLikes}) {
    final String field = sortByLikes ? 'likes' : 'createdAt';

    return _posts.orderBy(field, descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => VibeCard.fromFirestore(doc)).toList();
    });
  }

  // 5. select with AGGREGATION
  // counts how many cards a user has posted, without downloading them
  Future<int> countPostsByUser(String userId) async {
    final AggregateQuerySnapshot snapshot = await _posts
        .where('userId', isEqualTo: userId)
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  // aggregation - total and average likes across a user's cards.
  // sum() and average() need a userId + likes composite index; count()
  // does not, so the count still works while this one is building.
  Future<Map<String, num>> likeStatsByUser(String userId) async {
    try {
      final AggregateQuerySnapshot snapshot = await _posts
          .where('userId', isEqualTo: userId)
          .aggregate(sum('likes'), average('likes'))
          .get();

      return {
        'total': snapshot.getSum('likes') ?? 0,
        'average': snapshot.getAverage('likes') ?? 0,
      };
    } on FirebaseException catch (error) {
      // while the index is still building the query fails; show zeroes
      // rather than letting the provider retry in a loop
      if (error.code == 'failed-precondition') {
        return {'total': 0, 'average': 0};
      }

      rethrow;
    }
  }

  // ---------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------

  // SELECT with multiple values on the SAME field (whereIn) - used by the
  // Saved and Liked tabs. firestore caps whereIn at 30 values per query.
  Stream<List<VibeCard>> selectByIds(List<String> postIds) {
    if (postIds.isEmpty) {
      return Stream.value(<VibeCard>[]);
    }

    final List<String> capped = postIds.take(30).toList();

    return _posts.where(FieldPath.documentId, whereIn: capped).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => VibeCard.fromFirestore(doc)).toList();
    });
  }

  // stream of only the posts belonging to one user, for the profile screen
  Stream<List<VibeCard>> selectPostsByUser(String userId) {
    return _posts
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => VibeCard.fromFirestore(doc))
              .toList();
        });
  }

  // like / unlike uses an atomic increment so two users cannot overwrite
  // each other's like count
  Future<void> changeLikes(String postId, bool isLiking) async {
    await _posts.doc(postId).update({
      'likes': FieldValue.increment(isLiking ? 1 : -1),
    });
  }

  // converts firestore errors into simple messages for the user
  String getErrorMessage(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'You do not have permission to do that.';
      } else if (error.code == 'not-found') {
        return 'This vibe card no longer exists.';
      } else if (error.code == 'unavailable') {
        return 'No internet connection. Please try again.';
      } else if (error.code == 'failed-precondition') {
        return 'This query needs a database index. Check the debug console.';
      } else if (error.message != null) {
        return error.message!;
      }
    }

    return 'Something went wrong. Please try again.';
  }
}
