import 'dart:convert';

import 'package:http/http.dart' as http;

// what one iTunes lookup gives us back
class SongInfo {
  final String? artworkUrl;
  final String? previewUrl; // 30 second clip

  const SongInfo({this.artworkUrl, this.previewUrl});

  static const SongInfo empty = SongInfo();
}

// ADDITIONAL FEATURE - Web service consumption (iTunes Search API).
// looks up album artwork and a 30 second preview for each song the AI
// suggests. free, no API key, and CORS-enabled so it works on web too.
class MusicService {
  static const String _endpoint = 'https://itunes.apple.com/search';

  // one lookup per track is enough; results are remembered for the
  // lifetime of the app so switching between songs is instant
  static final Map<String, SongInfo> _cache = <String, SongInfo>{};

  String _key(String songName, String artist) =>
      '$songName|$artist'.toLowerCase();

  // returns artwork and preview for a song, or empty when nothing matches
  Future<SongInfo> lookup(String songName, String artist) async {
    final String key = _key(songName, artist);

    final SongInfo? cached = _cache[key];

    if (cached != null) {
      return cached;
    }

    try {
      final Uri uri = Uri.parse(
        '$_endpoint?term=${Uri.encodeComponent('$songName $artist')}'
        '&entity=song&limit=1',
      );

      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        _cache[key] = SongInfo.empty;
        return SongInfo.empty;
      }

      final Map<String, dynamic> body = jsonDecode(response.body);
      final List<dynamic> results = body['results'] ?? const [];

      if (results.isEmpty) {
        _cache[key] = SongInfo.empty;
        return SongInfo.empty;
      }

      final Map<String, dynamic> first = results.first;

      // iTunes always returns its closest guess, so a song that does not
      // exist comes back as something else. only accept it when the artist
      // matches the one we asked for.
      final String returnedArtist = (first['artistName'] ?? '')
          .toString()
          .toLowerCase();
      final String wantedArtist = artist.trim().toLowerCase();

      if (wantedArtist.isNotEmpty && !returnedArtist.contains(wantedArtist)) {
        _cache[key] = SongInfo.empty;
        return SongInfo.empty;
      }

      final String? small = first['artworkUrl100'];

      final SongInfo info = SongInfo(
        // the API returns a 100px thumbnail; swapping the size in the URL
        // gives a sharp image for the vibe card
        artworkUrl: small?.replaceAll('100x100bb', '400x400bb'),
        previewUrl: first['previewUrl'],
      );

      _cache[key] = info;

      return info;
    } catch (error) {
      // artwork and preview are both nice-to-haves, so a failure falls
      // back to the lettered placeholder rather than breaking the editor
      _cache[key] = SongInfo.empty;
      return SongInfo.empty;
    }
  }

  // preloads every suggestion in parallel so switching songs is instant
  Future<Map<String, SongInfo>> preloadAll(
    List<({String name, String artist})> songs,
  ) async {
    final Map<String, SongInfo> found = {};

    await Future.wait(
      songs.map((song) async {
        found[_key(song.name, song.artist)] = await lookup(
          song.name,
          song.artist,
        );
      }),
    );

    return found;
  }

  // reads an already-preloaded result without waiting
  SongInfo cached(String songName, String artist) =>
      _cache[_key(songName, artist)] ?? SongInfo.empty;
}
