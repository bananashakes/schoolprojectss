import 'dart:ui' show Offset;

import 'package:cloud_firestore/cloud_firestore.dart';

// model for one vibe card post stored in the "posts" collection
class VibeCard {
  final String postId;
  final String userId;
  final String userName;
  final String caption;
  // the fixed category used for filtering (one of five). the feed's
  // vibe filter and its composite index both query this field.
  final String vibe;

  // what the AI actually called this vibe, in its own words. shown on the
  // card so the label reads naturally instead of picking from a menu.
  final String vibeLabel;

  // the other wordings the AI offered for this same vibe, kept on the card
  // so the edit screen can still offer them long after the scan happened
  final List<String> vibeLabelOptions;

  // and the other songs it suggested, for the same reason. each entry holds
  // a name and an artist.
  final List<Map<String, String>> songOptions;

  // the meme names the AI picked, resolved through MemeLibrary when shown
  final List<String> memeOptions;

  // the expressive AI phrase, e.g. "im so done"
  final String auraLine;
  final String songName;
  final String songArtist;
  final String memeName;
  final String memeEmoji;
  final String imagePath;
  // flattened picture of the whole card. only older cards have one.
  final String imageBase64;

  // the two source photos, base64 in the document. firebase storage needs
  // a paid plan, so they are compressed to stay under the 1MB limit.
  final String outfitBase64;
  final String selfieBase64;

  // album artwork from the iTunes lookup, stored so the feed does not
  // re-query it for every card
  final String albumArtUrl;

  // where the four draggable overlays sit, as fractions of the card size
  // (0..1) so the layout survives being rendered at any scale
  final Offset memePosition;
  final Offset songPosition;
  final Offset selfiePosition;
  final Offset labelPosition;
  final Offset vibePosition;

  // true when the document stored a layout. older cards have none.
  final bool hasLayout;

  final int likes;
  final int comments;
  final bool isPublic;
  final DateTime createdAt;

  // the fixed categories the AI classifies into. the feed filters on
  // these, unlike vibeLabel which the AI writes freely.
  static const List<String> categories = [
    'bad girl energy',
    'night city aura',
    'main character',
    'chaotic pretty',
    'soft villain era',
  ];

  // where the overlays start out on a new card
  static const Offset defaultMemePosition = Offset(0.62, 0.55);
  static const Offset defaultSongPosition = Offset(0.06, 0.80);
  static const Offset defaultSelfiePosition = Offset(0.66, 0.04);
  static const Offset defaultLabelPosition = Offset(0.05, 0.05);
  // sits just under the aura line to begin with
  static const Offset defaultVibePosition = Offset(0.05, 0.24);

  VibeCard({
    required this.postId,
    required this.userId,
    required this.userName,
    required this.caption,
    required this.vibe,
    this.vibeLabel = '',
    this.vibeLabelOptions = const [],
    this.songOptions = const [],
    this.memeOptions = const [],
    this.auraLine = '',
    required this.songName,
    required this.songArtist,
    required this.memeName,
    required this.memeEmoji,
    required this.imagePath,
    this.imageBase64 = '',
    this.outfitBase64 = '',
    this.selfieBase64 = '',
    this.albumArtUrl = '',
    this.memePosition = defaultMemePosition,
    this.songPosition = defaultSongPosition,
    this.selfiePosition = defaultSelfiePosition,
    this.labelPosition = defaultLabelPosition,
    this.vibePosition = defaultVibePosition,
    this.hasLayout = false,
    required this.likes,
    required this.comments,
    required this.isPublic,
    required this.createdAt,
  });

  // reads one "x"/"y" pair out of the stored layout map, falling back to
  // where that overlay normally starts when the value is missing
  static Offset _readPosition(
    Map<String, dynamic>? layout,
    String key,
    Offset fallback,
  ) {
    if (layout == null) {
      return fallback;
    }

    final Object? x = layout['${key}X'];
    final Object? y = layout['${key}Y'];

    if (x is! num || y is! num) {
      return fallback;
    }

    // clamped because a corrupt value would push the overlay off the card
    return Offset(x.toDouble().clamp(0.0, 1.0), y.toDouble().clamp(0.0, 1.0));
  }

  // the stored song suggestions, skipping anything without a name
  static List<Map<String, String>> _readSongOptions(Object? raw) {
    if (raw is! List) {
      return const [];
    }

    final List<Map<String, String>> songs = [];

    for (final Object? item in raw) {
      if (item is! Map) {
        continue;
      }

      final String name = item['name']?.toString() ?? '';

      if (name.isEmpty) {
        continue;
      }

      songs.add({'name': name, 'artist': item['artist']?.toString() ?? ''});
    }

    return songs;
  }

  // builds a VibeCard from a firestore document
  factory VibeCard.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    final Map<String, dynamic>? layout = data['layout'] is Map
        ? Map<String, dynamic>.from(data['layout'])
        : null;

    return VibeCard(
      postId: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      caption: data['caption'] ?? '',
      vibe: data['vibe'] ?? '',
      vibeLabel: data['vibeLabel'] ?? '',
      vibeLabelOptions: data['vibeLabelOptions'] is List
          ? List<String>.from(
              (data['vibeLabelOptions'] as List).map((e) => e.toString()),
            )
          : const [],
      songOptions: _readSongOptions(data['songOptions']),
      memeOptions: data['memeOptions'] is List
          ? List<String>.from(
              (data['memeOptions'] as List).map((e) => e.toString()),
            )
          : const [],
      auraLine: data['auraLine'] ?? '',
      songName: data['songName'] ?? '',
      songArtist: data['songArtist'] ?? '',
      memeName: data['memeName'] ?? '',
      memeEmoji: data['memeEmoji'] ?? '',
      imagePath: data['imagePath'] ?? '',
      imageBase64: data['imageBase64'] ?? '',
      outfitBase64: data['outfitBase64'] ?? '',
      selfieBase64: data['selfieBase64'] ?? '',
      albumArtUrl: data['albumArtUrl'] ?? '',
      memePosition: _readPosition(layout, 'meme', defaultMemePosition),
      songPosition: _readPosition(layout, 'song', defaultSongPosition),
      selfiePosition: _readPosition(layout, 'selfie', defaultSelfiePosition),
      labelPosition: _readPosition(layout, 'label', defaultLabelPosition),
      vibePosition: _readPosition(layout, 'vibe', defaultVibePosition),
      hasLayout: layout != null,
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      isPublic: data['isPublic'] ?? true,
      // createdAt can be null for a split second while the server timestamp is written
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // converts this object into a map that firestore can store
  // postId is left out because firestore uses it as the document id
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'caption': caption,
      'vibe': vibe,
      'vibeLabel': vibeLabel,
      'vibeLabelOptions': vibeLabelOptions,
      'songOptions': songOptions,
      'memeOptions': memeOptions,
      'auraLine': auraLine,
      'songName': songName,
      'songArtist': songArtist,
      'memeName': memeName,
      'memeEmoji': memeEmoji,
      'imagePath': imagePath,
      'imageBase64': imageBase64,
      'outfitBase64': outfitBase64,
      'selfieBase64': selfieBase64,
      'albumArtUrl': albumArtUrl,
      // only written when this card really has a layout, so a card without
      // one is not mistaken for a composable card when it is read back
      if (hasLayout) 'layout': layoutToMap(),
      'likes': likes,
      'comments': comments,
      'isPublic': isPublic,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // the overlay positions in the shape firestore stores them
  Map<String, double> layoutToMap() {
    return {
      'memeX': memePosition.dx,
      'memeY': memePosition.dy,
      'songX': songPosition.dx,
      'songY': songPosition.dy,
      'selfieX': selfiePosition.dx,
      'selfieY': selfiePosition.dy,
      'labelX': labelPosition.dx,
      'labelY': labelPosition.dy,
      'vibeX': vibePosition.dx,
      'vibeY': vibePosition.dy,
    };
  }

  // true when this card can be redrawn from its parts. needs both a
  // source photo and a saved layout.
  bool get isLiveComposed =>
      hasLayout && (outfitBase64.isNotEmpty || imagePath.isNotEmpty);

  // what the card chip displays: the AI's own words when it wrote some,
  // otherwise the fixed category
  String get displayVibe => vibeLabel.isNotEmpty ? vibeLabel : vibe;

  // makes a copy with some fields changed, used by the edit screen
  VibeCard copyWith({
    String? caption,
    String? vibe,
    String? vibeLabel,
    List<String>? vibeLabelOptions,
    List<Map<String, String>>? songOptions,
    List<String>? memeOptions,
    String? auraLine,
    String? songName,
    String? songArtist,
    String? memeName,
    String? memeEmoji,
    String? imagePath,
    String? imageBase64,
    String? outfitBase64,
    String? selfieBase64,
    String? albumArtUrl,
    Offset? memePosition,
    Offset? songPosition,
    Offset? selfiePosition,
    Offset? labelPosition,
    Offset? vibePosition,
    bool? hasLayout,
    int? likes,
    int? comments,
    bool? isPublic,
  }) {
    return VibeCard(
      postId: postId,
      userId: userId,
      userName: userName,
      caption: caption ?? this.caption,
      vibe: vibe ?? this.vibe,
      vibeLabel: vibeLabel ?? this.vibeLabel,
      vibeLabelOptions: vibeLabelOptions ?? this.vibeLabelOptions,
      songOptions: songOptions ?? this.songOptions,
      memeOptions: memeOptions ?? this.memeOptions,
      auraLine: auraLine ?? this.auraLine,
      songName: songName ?? this.songName,
      songArtist: songArtist ?? this.songArtist,
      memeName: memeName ?? this.memeName,
      memeEmoji: memeEmoji ?? this.memeEmoji,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      outfitBase64: outfitBase64 ?? this.outfitBase64,
      selfieBase64: selfieBase64 ?? this.selfieBase64,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      memePosition: memePosition ?? this.memePosition,
      songPosition: songPosition ?? this.songPosition,
      selfiePosition: selfiePosition ?? this.selfiePosition,
      labelPosition: labelPosition ?? this.labelPosition,
      vibePosition: vibePosition ?? this.vibePosition,
      hasLayout: hasLayout ?? this.hasLayout,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt,
    );
  }
}
