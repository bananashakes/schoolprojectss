import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_vibe_result.dart';
import '../models/card_layout.dart';
import '../models/vibe_card.dart';
import '../providers/music_provider.dart';
import '../services/music_service.dart';
import '../services/preview_player_service.dart';
import '../providers/post_provider.dart';
import '../providers/user_provider.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/offline_banner.dart';
import '../widgets/share_bottom_sheet_widget.dart';
import '../widgets/vibe_card_canvas.dart';
import '../utils/meme_library.dart';
import '../theme/aura_theme.dart';
import '../widgets/aura_snack_bar.dart';

// what the upload screen passes into the editor
class CreateEditorArgs {
  final AiVibeResult aiResult;
  final Uint8List? cardImageBytes; // the outfit photo
  final Uint8List? selfieBytes;

  const CreateEditorArgs({
    required this.aiResult,
    this.cardImageBytes,
    this.selfieBytes,
  });
}

// second step of creating a vibe card
// user checks the generated card and edits the AI matches
class CreateEditorScreen extends ConsumerStatefulWidget {
  static const String routeName = '/create-editor';

  const CreateEditorScreen({super.key});

  @override
  ConsumerState<CreateEditorScreen> createState() => _CreateEditorScreenState();
}

class _CreateEditorScreenState extends ConsumerState<CreateEditorScreen> {
  static const Color _cardDark = Color(0xFF101018);
  static const Color _surface = Color(0xFF181827);
  static const Color _neonPurple = Color(0xFFBB86FC);

  // App Personalisation - live accent for the chosen Aura palette
  Color get _accent => AuraTheme.seed(ref.watch(auraPaletteProvider));
  static const Color _neonPink = Color(0xFFFF6EC7);
  static const Color _neonCyan = Color(0xFF03DAC6);
  static const Color _textPrimary = Color(0xFFF4F1FF);
  static const Color _textSecondary = Color(0xFF9B95B8);
  static const Color _border = Color(0xFF2E2448);
  static const Color _error = Color(0xFFFF6E8A);

  // caption is only shown when the user presses post
  final GlobalKey<FormState> _captionFormKey = GlobalKey<FormState>();
  final TextEditingController _captionController = TextEditingController();

  // what the AI returned for these photos, and the photo itself
  AiVibeResult? _aiResult;
  Uint8List? _cardImageBytes;
  Uint8List? _selfieBytes;
  bool _didLoadArgs = false;

  // where the draggable overlays sit, as fractions of the card size.
  //
  // deliberately a ValueNotifier rather than screen state: a drag reports a
  // new position on every pointer move, and calling setState that often
  // would rebuild the AI, music, meme and vibe panels too. only the card
  // itself listens to this, so only the card rebuilds while dragging.
  final ValueNotifier<CardLayout> _layout = ValueNotifier<CardLayout>(
    CardLayout.initial,
  );

  // every song's artwork + preview, preloaded together so switching
  // between songs is instant instead of triggering a fresh request
  Map<String, SongInfo> _songInfo = {};

  // which song is currently playing its preview clip
  String? _playingUrl;

  // keeps the badge in sync with the real player state
  StreamSubscription<PlayerState>? _playerSub;

  // held directly because ref cannot be used inside dispose()
  PreviewPlayerService? _player;

  String _songKey(int index) =>
      '${_songs[index]['name']}|${_songs[index]['artist']}'.toLowerCase();

  SongInfo _infoFor(int index) => _songInfo[_songKey(index)] ?? SongInfo.empty;

  String? get _albumArtUrl => _infoFor(_selectedSongIndex).artworkUrl;

  // the AI's punchy phrase, shown large on the card
  String _auraLine = '';

  // marks the canvas so the export feature can render it to PNG
  final GlobalKey _canvasBoundaryKey = GlobalKey();

  int _selectedSongIndex = 0;
  int _selectedMemeIndex = 0;
  int _selectedVibeIndex = 0;
  bool _isPosting = false;

  // these are the defaults, replaced by the AI suggestions on load
  List<Map<String, String>> _songs = [
    {
      'name': "Drop It Like It's Hot",
      'artist': 'Snoop Dogg',
      'vibe': 'confident',
      'short': 'D',
    },
    {'name': 'Strategy', 'artist': 'TWICE', 'vibe': 'main pop', 'short': 'S'},
    {
      'name': 'Espresso',
      'artist': 'Sabrina Carpenter',
      'vibe': 'cute chaos',
      'short': 'E',
    },
  ];

  List<Map<String, String>> _memes = MemeLibrary.all
      .take(3)
      .map(
        (option) => {
          'name': option.name,
          'emoji': option.emoji,
          'match': option.expression,
          'image': option.imagePath,
        },
      )
      .toList();

  // the wordings the "Next vibe" button cycles through. the AI's own three
  // wordings replace these once the photos have been scanned, so the list
  // below only stands in when that call could not be made.
  List<String> _vibes = VibeCard.categories;

  // the fixed category this card is filed under, classified by the AI.
  // cycling the wording never changes it, because the feed's vibe filter
  // and its composite index both query this field.
  String _category = 'main character';

  // the wording printed on the card
  String get _currentLabel => _vibes[_selectedVibeIndex];

  @override
  void initState() {
    super.initState();

    // the badge must clear when a clip ends on its own, not just when the
    // user stops it, otherwise the cover keeps showing a pause icon
    _player = ref.read(previewPlayerProvider);

    _playerSub = _player!.stateStream.listen((state) {
      if (!mounted) return;

      final bool finished = state.processingState == ProcessingState.completed;

      if (finished || !state.playing) {
        setState(() {
          _playingUrl = null;
        });
      }
    });
  }

  // route arguments only become available here, not in initState
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoadArgs) {
      return;
    }

    _didLoadArgs = true;

    final Object? argument = ModalRoute.of(context)?.settings.arguments;

    if (argument is! CreateEditorArgs) {
      return;
    }

    _applyAiResult(argument);
  }

  // fills the editor panels with what the AI suggested
  void _applyAiResult(CreateEditorArgs args) {
    final AiVibeResult result = args.aiResult;

    setState(() {
      _aiResult = result;
      _cardImageBytes = args.cardImageBytes;
      _selfieBytes = args.selfieBytes;
      _auraLine = result.auraLine;

      // the song panel now shows the AI's three picks
      if (result.songs.isNotEmpty) {
        _songs = result.songs.map((song) {
          return {
            'name': song.name,
            'artist': song.artist,
            'vibe': song.reason,
            'short': song.name.isEmpty ? '?' : song.name[0].toUpperCase(),
          };
        }).toList();
      }

      // and the meme panel shows the AI's three picks
      if (result.memes.isNotEmpty) {
        _memes = result.memes.map((meme) {
          return {
            'name': meme.name,
            'emoji': meme.emoji,
            'match': meme.match,
            'image': meme.imagePath,
          };
        }).toList();
      }

      // the AI's own wordings become what the user cycles through, so the
      // alternatives describe these photos instead of coming from a fixed
      // list. the fallback list is left in place if the AI returned none.
      if (result.vibeLabels.isNotEmpty) {
        _vibes = result.vibeLabels;
      }

      _selectedVibeIndex = 0;

      // the category is separate from the wording and is never cycled
      final String aiVibe = result.vibe.trim();

      if (aiVibe.isNotEmpty) {
        _category = aiVibe;
      }

      _selectedSongIndex = 0;
      _selectedMemeIndex = 0;

      // the AI's caption is offered as a starting point
      _captionController.text = result.caption;
    });

    _loadAlbumArt();
  }

  // WEB SERVICE - preloads artwork and preview clips for every suggestion.
  // the three lookups run in parallel and are cached, so this is one round
  // trip and switching songs afterwards costs nothing.
  Future<void> _loadAlbumArt() async {
    if (_songs.isEmpty) return;

    final List<({String name, String artist})> songs = _songs
        .map((song) => (name: song['name'] ?? '', artist: song['artist'] ?? ''))
        .toList();

    final Map<String, SongInfo> found = await ref
        .read(musicServiceProvider)
        .preloadAll(songs);

    if (!mounted) return;

    setState(() {
      _songInfo = found;
    });
  }

  // plays the 30 second clip for the chosen song, or stops it if the same
  // song is tapped again
  Future<void> _playPreview(int index) async {
    final String? url = _infoFor(index).previewUrl;

    if (url == null) {
      return;
    }

    final player = ref.read(previewPlayerProvider);

    await player.play(url);

    if (!mounted) return;

    setState(() {
      _playingUrl = player.currentUrl;
    });
  }

  // lets the user rewrite the AI's aura line in their own words
  Future<void> _editAuraLine() async {
    final TextEditingController controller = TextEditingController(
      text: _auraLine,
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final String? result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Edit your aura line',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLength: 40,
              maxLines: 2,
              textCapitalization: TextCapitalization.none,
              style: const TextStyle(color: _textPrimary, fontSize: 16),
              cursorColor: _accent,
              decoration: InputDecoration(
                hintText: 'e.g. im so done',
                hintStyle: const TextStyle(color: _textSecondary),
                counterStyle: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                ),
                filled: true,
                fillColor: _surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _accent, width: 1.5),
                ),
                errorStyle: const TextStyle(color: _error),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Write something for your card.';
                }

                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(ctx).pop(controller.text.trim());
              },
              child: const Text('Save', style: TextStyle(color: _neonPurple)),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _auraLine = result;
      });
    }
  }

  // moves one of the draggable overlays on the card.
  // no setState here on purpose - see the note on _layout above
  void _handleDrag(String element, Offset position) {
    _layout.value = _layout.value.moved(element, position);
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    // stop any preview so audio does not continue after leaving.
    // this uses the player captured in initState rather than ref, because
    // reading a provider here throws once the widget is disposed - and the
    // throw would skip the stop entirely, leaving the clip playing.
    _player?.stop();
    _captionController.dispose();
    _layout.dispose();
    super.dispose();
  }

  // lets the user cycle to a different vibe label manually
  void _regenerateVibe() {
    setState(() {
      _selectedVibeIndex = (_selectedVibeIndex + 1) % _vibes.length;
    });

    _showAuraSnackBar(
      'Vibe label changed',
      icon: Icons.auto_awesome_rounded,
      color: _neonPink,
    );
  }

  // CREATE - saves the finished vibe card into cloud firestore
  Future<void> _postVibeCard() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showAuraSnackBar(
        'Please log in before posting.',
        icon: Icons.error_outline_rounded,
        color: _error,
      );
      return;
    }

    // offline mode: posting writes to firestore, so block it early
    final bool isOnline = ref.read(isOnlineProvider).value ?? true;

    if (!isOnline) {
      _showAuraSnackBar(
        "You're offline. Connect to the internet to post.",
        icon: Icons.wifi_off_rounded,
        color: _error,
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    // the card is stored as the parts it was built from rather than as a
    // picture of itself, so every surface composes it again when it draws
    // it. that is what lets an edit change the card, and it also stores
    // less than the flattened picture did.
    // both photos were already resized and compressed when they were picked
    // (ImagePicker maxWidth / imageQuality), so they only need encoding here
    final String outfitBase64 = _cardImageBytes == null
        ? ''
        : base64Encode(_cardImageBytes!);
    final String selfieBase64 = _selfieBytes == null
        ? ''
        : base64Encode(_selfieBytes!);

    // builds the document from what the user picked in the editor
    final VibeCard newCard = VibeCard(
      postId: '', // firestore generates the real id on insert
      userId: user.uid,
      userName:
          user.displayName ?? user.email?.split('@').first ?? 'aurafarmer',
      caption: _captionController.text.trim(),
      vibe: _category,
      vibeLabel: _currentLabel,
      // the AI's other wordings travel with the card so the edit screen
      // can still offer them later
      vibeLabelOptions: _vibes,
      // the AI's other song picks travel with the card so the edit
      // screen can offer them instead of a fixed list
      songOptions: _songs
          .map(
            (song) => {
              'name': song['name'] ?? '',
              'artist': song['artist'] ?? '',
            },
          )
          .toList(),
      memeOptions: _memes.map((meme) => meme['name'] ?? '').toList(),
      auraLine: _auraLine,
      songName: _songs[_selectedSongIndex]['name'] ?? '',
      songArtist: _songs[_selectedSongIndex]['artist'] ?? '',
      memeName: _memes[_selectedMemeIndex]['name'] ?? '',
      memeEmoji: _memes[_selectedMemeIndex]['emoji'] ?? '',
      // only the sample cards use a bundled asset for their picture
      imagePath: '',
      // no flattened picture: the card is composed from the parts below
      imageBase64: '',
      outfitBase64: outfitBase64,
      selfieBase64: selfieBase64,
      // saved so the feed can draw the song chip without asking the web
      // service again for every card it shows
      albumArtUrl: _albumArtUrl ?? '',
      memePosition: _layout.value.meme,
      songPosition: _layout.value.song,
      selfiePosition: _layout.value.selfie,
      labelPosition: _layout.value.label,
      vibePosition: _layout.value.vibe,
      hasLayout: true,
      likes: 0,
      comments: 0,
      isPublic: true,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(firestoreServiceProvider).insertPost(newCard);

      if (!mounted) {
        return;
      }

      setState(() {
        _isPosting = false;
      });

      _showAuraSnackBar(
        'Vibe card posted',
        icon: Icons.check_circle_rounded,
        color: _neonCyan,
      );
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPosting = false;
      });

      // AlertDialog feedback so failures are not only a snackbar
      _showErrorDialog(
        ref.read(firestoreServiceProvider).getErrorMessage(error),
      );
    }
  }

  // shows a blocking error popup when saving fails
  void _showErrorDialog(String message) {
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
              Icon(Icons.error_outline_rounded, color: _error, size: 22),
              SizedBox(width: 10),
              Text(
                'Could not post',
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
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('OK', style: TextStyle(color: _neonPurple)),
            ),
          ],
        );
      },
    );
  }

  // shows styled messages to the user
  void _showAuraSnackBar(
    String message, {
    IconData icon = Icons.info_outline_rounded,
    Color color = _neonPurple,
  }) {
    showAuraSnackBar(
      context,
      message,
      icon: icon,
      backgroundColor: _cardDark,
      iconColor: color,
      borderColor: color,
      textColor: _textPrimary,
      borderOpacity: 0.55,
      shadowColor: color,
      shadowOpacity: 0.25,
      blurRadius: 18,
      fontSize: 14,
      shadowOffset: Offset.zero,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
    );
  }

  // opens caption form before posting
  void _showPostSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _captionFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _textSecondary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Post your Vibe Card',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add a short caption before posting to your feed.',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _captionController,
                  maxLength: 150,
                  maxLines: 3,
                  style: const TextStyle(color: _textPrimary),
                  cursorColor: _accent,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: 'e.g. fit check went too hard',
                    hintStyle: const TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                    ),
                    counterStyle: const TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                    ),
                    filled: true,
                    fillColor: _surface,
                    contentPadding: const EdgeInsets.all(14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _accent, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _error),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _error),
                    ),
                    errorStyle: const TextStyle(color: _error),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a caption';
                    }

                    if (value.trim().length < 3) {
                      return 'Caption must be at least 3 characters';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!_captionFormKey.currentState!.validate()) {
                        return;
                      }

                      FocusScope.of(ctx).unfocus();
                      Navigator.of(ctx).pop();
                      _postVibeCard();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text(
                      'Post Vibe Card',
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
  }

  // opens the same share popup as the card detail screen.
  // the capture key lets the user export the card straight from the editor
  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ShareBottomSheetWidget(
          showMessage: (message) {
            _showAuraSnackBar(
              message,
              icon: Icons.ios_share_rounded,
              color: _neonCyan,
            );
          },
          captureKey: _canvasBoundaryKey,
          fileName: 'aurafarm_new_card.png',
          shareText:
              '${_captionController.text.trim()} — $_currentLabel vibe on AuraFarm ✨',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                child: Column(
                  children: [
                    _buildVibeCardCanvas(),
                    _buildAiInsightPanel(),
                    const SizedBox(height: 14),
                    _buildMusicPanel(),
                    const SizedBox(height: 12),
                    _buildMemePanel(),
                    const SizedBox(height: 12),
                    _buildVibeLabelPanel(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // top bar with post and export actions
  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      toolbarHeight: 70,
      leadingWidth: 54,
      leading: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _textPrimary,
            size: 22,
          ),
        ),
      ),
      titleSpacing: 0,
      title: const Text(
        'Create Vibe Card',
        style: TextStyle(
          color: _textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        Center(
          child: SizedBox(
            height: 44,
            child: TextButton(
              onPressed: _isPosting ? null : _showPostSheet,
              style: TextButton.styleFrom(
                foregroundColor: _textPrimary,
                backgroundColor: _surface,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: _border),
                ),
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Post',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _showExportSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 8,
                  shadowColor: _accent.withValues(alpha: 0.5),
                ),
                child: const Text(
                  'Save/Export',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // main vibe card preview using exported design image
  Widget _buildVibeCardCanvas() {
    return RepaintBoundary(
      key: _canvasBoundaryKey,
      child: _buildVibeCardCanvasInner(),
    );
  }

  Widget _buildVibeCardCanvasInner() {
    return AspectRatio(
      aspectRatio: VibeCardCanvas.aspect,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _accent.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.20),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        // the composed card: outfit photo, selfie inset, song chip and meme.
        // only this subtree listens to the layout, so a drag rebuilds the
        // card and nothing else on the screen.
        child: ValueListenableBuilder<CardLayout>(
          valueListenable: _layout,
          builder: (context, layout, child) => VibeCardCanvas(
            outfitBytes: _cardImageBytes,
            selfieBytes: _selfieBytes,
            vibe: _currentLabel,
            auraLine: _auraLine,
            songName: _songs.isEmpty
                ? ''
                : _songs[_selectedSongIndex]['name'] ?? '',
            songArtist: _songs.isEmpty
                ? ''
                : _songs[_selectedSongIndex]['artist'] ?? '',
            albumArtUrl: _albumArtUrl,
            memeImagePath: MemeLibrary.imageFor(
              _memes.isEmpty ? '' : _memes[_selectedMemeIndex]['name'] ?? '',
            ),
            memePosition: layout.meme,
            songPosition: layout.song,
            selfiePosition: layout.selfie,
            labelPosition: layout.label,
            vibePosition: layout.vibe,
            onDrag: _handleDrag,
            onLabelTap: _editAuraLine,
          ),
        ),
      ),
    );
  }

  // shows what the AI actually read from the two photos.
  // this is the visible proof that the scan happened, and it is the part
  // to point at during the demo.
  // one compact line proving the AI classified both photos.
  // deliberately short: the AI is a backend classifier, not a narrator.
  Widget _buildAiInsightPanel() {
    final AiVibeResult? result = _aiResult;

    if (result == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _neonCyan.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: _neonCyan, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI read: ${result.expression}  ·  ${result.outfit}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // reusable dark panel
  Widget _buildPanel({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _accent.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(color: _accent.withValues(alpha: 0.10), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _neonPurple, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.help_outline_rounded,
                color: _textSecondary.withValues(alpha: 0.65),
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  Widget _buildMusicPanel() {
    return _buildPanel(
      icon: Icons.music_note_rounded,
      title: 'AI Music Suggestions',
      subtitle: 'Choose one song for your vibe',
      child: SizedBox(
        height: 105,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _songs.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final song = _songs[index];
            final bool selected = index == _selectedSongIndex;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSongIndex = index;
                });

                // artwork is already preloaded, so just start the clip
                _playPreview(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 148,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected ? _accent.withValues(alpha: 0.13) : _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? _accent : _border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        _buildAlbumCoverWithPlayState(
                          index: index,
                          artUrl: _infoFor(index).artworkUrl,
                          size: 50,
                          selected: selected,
                          shortText: song['short']!,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song['name']!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song['artist']!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                song['vibe']!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _neonCyan,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected
                            ? _neonPurple
                            : _textSecondary.withValues(alpha: 0.4),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // album cover plus a small play / pause badge, so the user can see
  // which clip is running and tap the same song again to stop it
  Widget _buildAlbumCoverWithPlayState({
    required int index,
    required double size,
    required bool selected,
    required String shortText,
    String? artUrl,
  }) {
    final String? preview = _infoFor(index).previewUrl;
    final bool isThisPlaying = preview != null && _playingUrl == preview;

    return Stack(
      children: [
        _buildAlbumCover(
          size: size,
          selected: selected,
          shortText: shortText,
          artUrl: artUrl,
        ),
        if (preview != null)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(
                  alpha: isThisPlaying ? 0.45 : 0.2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white.withValues(alpha: isThisPlaying ? 1 : 0.85),
                size: size * 0.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAlbumCover({
    required double size,
    required bool selected,
    required String shortText,
    String? artUrl,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        // real cover art from the iTunes lookup, with the lettered tile
        // as the fallback while it loads or when nothing matched
        child: artUrl == null
            ? _buildLetterCover(selected, shortText)
            : Image.network(
                artUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildLetterCover(selected, shortText);
                },
              ),
      ),
    );
  }

  Widget _buildLetterCover(bool selected, String shortText) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: selected ? [_neonPurple, _neonPink] : [_surface, _cardDark],
        ),
      ),
      child: Center(
        child: Text(
          shortText,
          style: TextStyle(
            color: selected ? Colors.white : _textSecondary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMemePanel() {
    return _buildPanel(
      icon: Icons.auto_awesome_rounded,
      title: 'AI Meme Match',
      subtitle: 'Generated from your selfie',
      child: Row(
        children: List.generate(_memes.length, (index) {
          final meme = _memes[index];
          final bool selected = index == _selectedMemeIndex;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == _memes.length - 1 ? 0 : 9,
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMemeIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 105,
                  decoration: BoxDecoration(
                    color: selected
                        ? _neonPink.withValues(alpha: 0.12)
                        : _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? _neonPink : _border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Image.asset(
                            meme['image'] ??
                                MemeLibrary.imageFor(meme['name'] ?? ''),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                meme['emoji'] ?? '',
                                style: const TextStyle(fontSize: 34),
                              );
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected
                              ? _neonPink
                              : _textSecondary.withValues(alpha: 0.4),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVibeLabelPanel() {
    return _buildPanel(
      icon: Icons.auto_awesome_rounded,
      title: 'AI Vibe Label',
      subtitle: 'Based on your outfit and selfie',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _currentLabel,
                style: const TextStyle(
                  color: _neonPink,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _regenerateVibe,
              style: TextButton.styleFrom(
                foregroundColor: _textPrimary,
                backgroundColor: _surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: _border),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Next vibe', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
