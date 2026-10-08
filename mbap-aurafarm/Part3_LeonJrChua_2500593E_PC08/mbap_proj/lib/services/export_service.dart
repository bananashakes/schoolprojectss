import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// ADDITIONAL FEATURE - Vibe Card Export (from the Part 1 proposal)
// renders the card widget to a PNG the user can save or share
class ExportService {
  // captures whatever is inside the RepaintBoundary as PNG bytes.
  // pixelRatio 3 keeps it sharp enough to repost.
  Future<Uint8List> captureCard(
    GlobalKey boundaryKey, {
    double pixelRatio = 3.0,
  }) async {
    final RenderObject? renderObject = boundaryKey.currentContext
        ?.findRenderObject();

    if (renderObject is! RenderRepaintBoundary) {
      throw Exception('The vibe card is not ready to export yet.');
    }

    final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);

    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('The vibe card could not be converted to an image.');
    }

    return byteData.buffer.asUint8List();
  }

  // opens the system share sheet with the PNG attached.
  // web falls back to a download when the browser cannot share files.
  Future<void> shareCard({
    required Uint8List pngBytes,
    required String fileName,
    String message = 'Made with AuraFarm ✨',
  }) async {
    final XFile file = XFile.fromData(
      pngBytes,
      name: fileName,
      mimeType: 'image/png',
    );

    await SharePlus.instance.share(ShareParams(files: [file], text: message));
  }

  // opens another app. returns false when it is not installed, so the
  // caller can say so.
  Future<bool> openApp(String url) async {
    final Uri uri = Uri.parse(url);

    if (!await canLaunchUrl(uri)) {
      return false;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // share links. instagram and tiktok have no share-text URL, so those
  // just open the app.
  String whatsAppUrl(String text) =>
      'https://wa.me/?text=${Uri.encodeComponent(text)}';

  String telegramUrl(String text) =>
      'https://t.me/share/url?url=${Uri.encodeComponent(text)}';

  String instagramUrl() => 'https://www.instagram.com/';

  String tikTokUrl() => 'https://www.tiktok.com/upload';

  String snapchatUrl() => 'https://www.snapchat.com/';

  // turns errors into messages the user can understand
  String getErrorMessage(Object error) {
    final String text = error.toString();

    if (text.contains('not ready to export')) {
      return 'Please wait for the card to finish loading, then try again.';
    }

    if (text.contains('could not be converted')) {
      return 'The card could not be saved as an image. Please try again.';
    }

    if (kIsWeb) {
      return 'Your browser blocked the download. Try a different browser.';
    }

    return 'Could not export the vibe card. Please try again.';
  }
}
