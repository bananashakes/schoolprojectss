import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/export_provider.dart';
import '../services/export_service.dart';

// ADDITIONAL FEATURE - Vibe Card Export (see Part 1 proposal)
// reusable share popup used by the card detail, create and profile screens.
// when a captureKey is provided, the sheet can render that widget into a
// real PNG and hand it to the system share dialog. the app buttons open
// the actual external apps through url_launcher.
class ShareBottomSheetWidget extends ConsumerStatefulWidget {
  final void Function(String message) showMessage;
  final String title;
  final String subtitle;

  // RepaintBoundary key of the vibe card to export. when this is null the
  // sheet only offers link sharing (e.g. sharing a profile).
  final GlobalKey? captureKey;

  // file name used for the exported PNG
  final String fileName;

  // text attached to shares and used by the copy button
  final String shareText;

  const ShareBottomSheetWidget({
    super.key,
    required this.showMessage,
    this.title = 'Export Your Vibe',
    this.subtitle = 'Save & Share',
    this.captureKey,
    this.fileName = 'aurafarm_vibe_card.png',
    this.shareText = 'Check out my vibe card on AuraFarm ✨',
  });

  @override
  ConsumerState<ShareBottomSheetWidget> createState() =>
      _ShareBottomSheetWidgetState();
}

class _ShareBottomSheetWidgetState
    extends ConsumerState<ShareBottomSheetWidget> {
  static const Color _sheetDark = Color(0xFF17151A);
  static const Color _actionDark = Color(0xFF242128);
  static const Color _softPurple = Color(0xFFB28CFF);
  static const Color _textPrimary = Color(0xFFF7F0FF);
  static const Color _textMuted = Color(0xFF9A8FA5);

  bool _isExporting = false;

  ExportService get _exporter => ref.read(exportServiceProvider);

  // captures the vibe card as a PNG and opens the system share dialog,
  // which includes saving to the device on both web and android
  Future<void> _saveOrShareImage() async {
    final GlobalKey? key = widget.captureKey;

    if (key == null || _isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final bytes = await _exporter.captureCard(key);

      await _exporter.shareCard(
        pngBytes: bytes,
        fileName: widget.fileName,
        message: widget.shareText,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      widget.showMessage('Vibe card exported ✨');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isExporting = false;
      });

      widget.showMessage(_exporter.getErrorMessage(error));
    }
  }

  // opens one of the external apps from the proposal's share list
  Future<void> _openExternalApp(String name, String url) async {
    final bool opened = await _exporter.openApp(url);

    if (!mounted) return;

    Navigator.of(context).pop();

    if (opened) {
      widget.showMessage('Opening $name...');
    } else {
      widget.showMessage('$name could not be opened on this device.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _sheetDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              const Divider(color: Color(0xFF2B2830), height: 1),
              _buildShareApps(context),
              const SizedBox(height: 12),
              _buildActions(context),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _actionDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _softPurple,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.subtitle,
                  style: const TextStyle(color: _textMuted, fontSize: 14),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Container(
              width: 39,
              height: 39,
              decoration: const BoxDecoration(
                color: Color(0xFF2B2830),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: _textMuted,
                size: 25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareApps(BuildContext context) {
    // each entry opens the real app / site through url_launcher
    final List<Map<String, String>> apps = [
      {
        'name': 'WhatsApp',
        'image': 'images/logo_whatsapp.png.jpg',
        'url': _exporter.whatsAppUrl(widget.shareText),
      },
      {
        'name': 'Instagram',
        'image': 'images/logo_instagram.png.png',
        'url': _exporter.instagramUrl(),
      },
      {
        'name': 'TikTok',
        'image': 'images/logo_tiktok.png.webp',
        'url': _exporter.tikTokUrl(),
      },
      {
        'name': 'Snapchat',
        'image': 'images/logo_snapchat.png.webp',
        'url': _exporter.snapchatUrl(),
      },
    ];

    return SizedBox(
      height: 108,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: apps.map((app) {
          String name = app['name']!;
          String imagePath = app['image']!;
          String url = app['url']!;

          return InkWell(
            onTap: () {
              _openExternalApp(name, url);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 57,
                  height: 57,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.image_not_supported_rounded,
                        color: Colors.black54,
                        size: 28,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(color: _textPrimary, fontSize: 13),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
            // export only appears when there is a card to capture
            if (widget.captureKey != null)
              _buildActionTile(
                title: 'Save / Share as image',
                icon: Icons.download_rounded,
                isFirst: true,
                isLoading: _isExporting,
                onTap: _saveOrShareImage,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required bool isFirst,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: _actionDark,
          border: Border(
            top: isFirst
                ? BorderSide.none
                : const BorderSide(color: Color(0xFF343039), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(color: _textPrimary, fontSize: 16),
            ),
            const Spacer(),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _softPurple,
                ),
              )
            else
              Icon(icon, color: _textPrimary, size: 24),
          ],
        ),
      ),
    );
  }
}
