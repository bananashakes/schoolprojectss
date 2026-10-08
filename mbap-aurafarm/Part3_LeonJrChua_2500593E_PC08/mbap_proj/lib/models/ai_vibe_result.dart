import '../utils/meme_library.dart';

// what the AI suggests for one song match
class AiSong {
  final String name;
  final String artist;
  final String reason;

  AiSong({required this.name, required this.artist, required this.reason});

  factory AiSong.fromJson(Map<String, dynamic> json) {
    return AiSong(
      name: json['name']?.toString() ?? 'Unknown song',
      artist: json['artist']?.toString() ?? 'Unknown artist',
      reason: json['reason']?.toString() ?? '',
    );
  }
}

// what the AI suggests for one meme match.
// the name is matched against the local meme library so every suggestion
// resolves to real artwork rather than an emoji.
class AiMeme {
  final String name;
  final String emoji;
  final String match;
  final String imagePath;

  AiMeme({
    required this.name,
    required this.emoji,
    required this.match,
    required this.imagePath,
  });

  factory AiMeme.fromJson(Map<String, dynamic> json) {
    final String rawName = json['name']?.toString() ?? '';
    final MemeOption option = MemeLibrary.byName(rawName);

    return AiMeme(
      name: option.name,
      emoji: option.emoji,
      match: json['match']?.toString() ?? option.expression,
      imagePath: option.imagePath,
    );
  }
}

// the full result of scanning the selfie and the outfit photo
class AiVibeResult {
  final String expression; // what the AI read from the face
  final String outfit; // what the AI read from the outfit
  final String vibe; // the fixed category, used for filtering

  // the AI's own wordings for this vibe. the first is used on the card and
  // the rest are what the "Next vibe" button cycles through, so the
  // alternatives describe these photos instead of coming from a fixed list.
  final List<String> vibeLabels;

  final String auraLine; // the expressive phrase shown on the card
  final String caption; // a suggested caption
  final List<AiSong> songs;
  final List<AiMeme> memes;

  AiVibeResult({
    required this.expression,
    required this.outfit,
    required this.vibe,
    this.vibeLabels = const [],
    this.auraLine = '',
    required this.caption,
    required this.songs,
    required this.memes,
  });

  // the wording the card starts out with
  String get vibeLabel => vibeLabels.isEmpty ? '' : vibeLabels.first;

  // reads the wordings out of the reply, dropping blanks and duplicates.
  // an older style reply with a single "vibeLabel" string still works.
  static List<String> _readLabels(Map<String, dynamic> json) {
    final Object? raw = json['vibeLabels'];

    final List<String> labels = raw is List
        ? raw.map((item) => item.toString().trim()).toList()
        : [json['vibeLabel']?.toString().trim() ?? ''];

    final List<String> cleaned = [];

    for (final String label in labels) {
      if (label.isNotEmpty && !cleaned.contains(label)) {
        cleaned.add(label);
      }
    }

    return cleaned;
  }

  factory AiVibeResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> songList = json['songs'] as List<dynamic>? ?? [];
    final List<dynamic> memeList = json['memes'] as List<dynamic>? ?? [];

    return AiVibeResult(
      expression: json['expression']?.toString() ?? 'neutral',
      outfit: json['outfit']?.toString() ?? 'casual fit',
      vibe: json['vibe']?.toString() ?? 'main character',
      vibeLabels: _readLabels(json),
      auraLine: json['auraLine']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      songs: songList
          .map((item) => AiSong.fromJson(item as Map<String, dynamic>))
          .toList(),
      memes: memeList
          .map((item) => AiMeme.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  // used when the AI call fails, so the editor still has something to show
  factory AiVibeResult.fallback() {
    return AiVibeResult(
      expression: 'could not read expression',
      outfit: 'could not read outfit',
      vibe: 'main character',
      vibeLabels: const ['main character'],
      auraLine: 'main character behaviour',
      caption: '',
      songs: [
        AiSong(
          name: "Drop It Like It's Hot",
          artist: 'Snoop Dogg',
          reason: 'default pick',
        ),
        AiSong(name: 'Strategy', artist: 'TWICE', reason: 'default pick'),
        AiSong(
          name: 'Espresso',
          artist: 'Sabrina Carpenter',
          reason: 'default pick',
        ),
      ],
      memes: MemeLibrary.all
          .take(3)
          .map(
            (option) => AiMeme(
              name: option.name,
              emoji: option.emoji,
              match: option.expression,
              imagePath: option.imagePath,
            ),
          )
          .toList(),
    );
  }
}
