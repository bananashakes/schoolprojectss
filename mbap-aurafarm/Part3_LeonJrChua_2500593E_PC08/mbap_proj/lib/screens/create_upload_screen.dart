import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'create_editor_screen.dart';
import '../models/ai_vibe_result.dart';
import '../providers/ai_provider.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/bottom_nav_widget.dart';
import '../widgets/ai_loading_overlay.dart';
import '../widgets/offline_banner.dart';

// first step of creating a vibe card
// user picks an outfit photo and a selfie, then the AI reads both
class CreateUploadScreen extends ConsumerStatefulWidget {
  static const String routeName = '/create';

  const CreateUploadScreen({super.key});

  @override
  ConsumerState<CreateUploadScreen> createState() => _CreateUploadScreenState();
}

class _CreateUploadScreenState extends ConsumerState<CreateUploadScreen> {
  // the real image bytes, kept in memory so they work on web and mobile
  Uint8List? _outfitBytes;
  Uint8List? _selfieBytes;

  bool _isGenerating = false;

  bool get _hasOutfitImage => _outfitBytes != null;
  bool get _hasSelfieImage => _selfieBytes != null;

  static const Color _cardDark = Color(0xFF101018);
  static const Color _surface = Color(0xFF181827);
  static const Color _neonPurple = Color(0xFF8B5CF6);
  static const Color _neonPink = Color(0xFFFF6EC7);
  static const Color _neonCyan = Color(0xFF03DAC6);
  static const Color _textPrimary = Color(0xFFF4F1FF);
  static const Color _textSecondary = Color(0xFF9B95B8);
  static const Color _border = Color(0xFF2E2448);

  bool get _canGenerate {
    return _hasOutfitImage && _hasSelfieImage;
  }

  // lets the user choose between the camera and the photo gallery
  Future<void> _pickImage(String type) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _textSecondary,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: _neonPurple,
                ),
                title: const Text(
                  'Take a photo',
                  style: TextStyle(color: _textPrimary, fontSize: 15),
                ),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: _neonPink,
                ),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(color: _textPrimary, fontSize: 15),
                ),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    try {
      // the photo is resized and compressed so the upload stays small
      // and so it fits inside a firestore document later
      final XFile? file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (file == null) {
        return;
      }

      final Uint8List bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        if (type == 'outfit') {
          _outfitBytes = bytes;
        } else {
          _selfieBytes = bytes;
        }
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage('Could not open that photo. Please try another one.');
    }
  }

  // simple snackbar feedback for this screen
  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: _surface));
  }

  // moves the user to the editor screen
  Future<void> _generateVibeCard() async {
    if (!_canGenerate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add both photos first')),
      );
      return;
    }

    // offline mode: AI generation needs the network, so stop early with
    // clear feedback instead of a confusing timeout
    final bool isOnline = ref.read(isOnlineProvider).value ?? true;

    if (!isOnline) {
      _showMessage("You're offline. Connect to the internet to generate.");
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // APPLIED AI FEATURE
      // sends both photos to Gemini, which reads the expression and the
      // outfit and returns a vibe label with song and meme matches
      final AiVibeResult result = await ref
          .read(aiServiceProvider)
          .analyseVibe(selfieBytes: _selfieBytes!, outfitBytes: _outfitBytes!);

      if (!mounted) {
        return;
      }

      setState(() {
        _isGenerating = false;
      });

      // the editor receives the AI result and the photo to put on the card
      Navigator.of(context).pushNamed(
        CreateEditorScreen.routeName,
        arguments: CreateEditorArgs(
          aiResult: result,
          cardImageBytes: _outfitBytes!,
          selfieBytes: _selfieBytes,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isGenerating = false;
      });

      _showAiErrorDialog(ref.read(aiServiceProvider).getErrorMessage(error));
    }
  }

  // explains what went wrong and offers to continue without the AI
  void _showAiErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: _neonPink, size: 22),
              SizedBox(width: 10),
              Text(
                'AI could not read it',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: _textSecondary, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Try again',
                style: TextStyle(color: _textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();

                // still lets the user make a card using the default options
                Navigator.of(context).pushNamed(
                  CreateEditorScreen.routeName,
                  arguments: CreateEditorArgs(
                    aiResult: AiVibeResult.fallback(),
                    cardImageBytes: _outfitBytes,
                    selfieBytes: _selfieBytes,
                  ),
                );
              },
              child: const Text(
                'Continue without AI',
                style: TextStyle(color: _neonPurple),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const OfflineBanner(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(),
                        const SizedBox(height: 18),
                        _buildPhotoArea(),
                        const SizedBox(height: 18),
                        _buildAiPreviewCard(),
                        const SizedBox(height: 20),
                        _buildGenerateButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // covers the screen while Gemini is reading the photos
          if (_isGenerating) const Positioned.fill(child: AiLoadingOverlay()),
        ],
      ),
      bottomNavigationBar: const BottomNavWidget(selectedIndex: 1),
    );
  }

  // returns to the previous screen or falls back to home
  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  // top app bar
  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary),
        onPressed: _handleBack,
      ),
      title: const Text(
        'Create Vibe Card',
        style: TextStyle(
          color: _textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _neonPurple.withValues(alpha: 0.45)),
              ),
              child: const Text(
                'Step 1 / 2',
                style: TextStyle(
                  color: _neonPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // short intro section
  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _neonPurple.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: _neonPurple.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -8,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: _neonPink.withValues(alpha: 0.22),
              size: 80,
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload your fit + face',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'AuraFarm uses both photos to create your song match, meme match and vibe label.',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // photo upload section
  Widget _buildPhotoArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photos needed',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Transform.rotate(
                angle: -3 * math.pi / 180,
                child: _buildUploadCard(
                  type: 'outfit',
                  title: 'Outfit',
                  subtitle: 'Full body fit pic',
                  icon: Icons.checkroom_rounded,
                  accentColor: _neonPurple,
                  isSelected: _hasOutfitImage,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Transform.rotate(
                angle: 3 * math.pi / 180,
                child: _buildUploadCard(
                  type: 'selfie',
                  title: 'Selfie',
                  subtitle: 'Expression pic',
                  icon: Icons.face_retouching_natural_rounded,
                  accentColor: _neonPink,
                  isSelected: _hasSelfieImage,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // reusable upload card
  Widget _buildUploadCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        _pickImage(type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 230,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.10) : _cardDark,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? accentColor.withValues(alpha: 0.8) : _border,
            width: isSelected ? 1.7 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.3),
              blurRadius: isSelected ? 20 : 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: isSelected
                    ? _buildSelectedPreview(
                        accentColor,
                        type == 'outfit' ? _outfitBytes : _selfieBytes,
                      )
                    : _buildEmptyPreview(icon, accentColor),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: accentColor,
                  size: 21,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSelected ? '$title ready' : title,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isSelected ? 'Photo added' : subtitle,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // empty upload preview
  Widget _buildEmptyPreview(IconData icon, Color accentColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: accentColor, size: 38),
        const SizedBox(height: 10),
        const Text(
          'Tap to upload',
          style: TextStyle(color: _textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  // selected upload preview
  // shows the photo the user actually picked
  Widget _buildSelectedPreview(Color accentColor, Uint8List? bytes) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: bytes == null
                ? Container(color: Colors.black)
                : Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: accentColor, size: 18),
          ),
        ),
      ],
    );
  }

  // shows what the AI will generate from the two photos
  Widget _buildAiPreviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _neonCyan.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: _neonCyan, size: 20),
              SizedBox(width: 8),
              Text(
                'AI will analyse your photos to generate:',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildAiSmallBox(
                icon: Icons.music_note_rounded,
                label: 'Song Match',
                color: _neonPurple,
              ),
              const SizedBox(width: 10),
              _buildAiSmallBox(
                icon: Icons.image_rounded,
                label: 'Meme Match',
                color: _neonPink,
              ),
              const SizedBox(width: 10),
              _buildAiSmallBox(
                icon: Icons.bolt_rounded,
                label: 'Vibe Match',
                color: _neonCyan,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // small AI result box
  Widget _buildAiSmallBox({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // generate button at bottom
  Widget _buildGenerateButton() {
    final bool active = _canGenerate && !_isGenerating;

    return Column(
      children: [
        Text(
          active
              ? 'Both photos added, ready to generate'
              : 'Add 2 photos to continue',
          style: TextStyle(
            color: _textSecondary.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 10),

        Center(
          child: SizedBox(
            width: 310,
            height: 48,
            child: ElevatedButton(
              onPressed: active ? _generateVibeCard : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: active ? const Color(0xFF8B5CF6) : _surface,
                disabledBackgroundColor: _surface,
                elevation: active ? 5 : 0,
                shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide.none,
              ),
              child: _isGenerating
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: active ? Colors.white : _textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Generate Vibe Card',
                          style: TextStyle(
                            color: active ? Colors.white : _textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
