import 'dart:convert';
import 'dart:typed_data';

// decoded photos for the cards on screen.
// base64 decoding is expensive and Image.memory cannot cache a list that
// is rebuilt each frame, so without this the feed re-decodes every photo
// on every rebuild.
class PhotoCache {
  PhotoCache._();

  static final Map<String, Uint8List> _decoded = <String, Uint8List>{};

  // a live card holds two photos, so this is deliberately larger than the
  // number of cards the feed keeps on screen
  static const int _maxEntries = 80;

  // decoded bytes for some base64 text, or null when it will not decode
  static Uint8List? decode(String key, String base64Text) {
    if (base64Text.isEmpty) {
      return null;
    }

    final Uint8List? cached = _decoded[key];

    if (cached != null) {
      return cached;
    }

    try {
      final Uint8List bytes = base64Decode(base64Text);

      // simple size cap so a long session cannot grow without limit
      if (_decoded.length >= _maxEntries) {
        _decoded.remove(_decoded.keys.first);
      }

      _decoded[key] = bytes;

      return bytes;
    } catch (error) {
      return null;
    }
  }
}
