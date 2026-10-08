import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_screen.dart';
import '../models/vibe_card.dart';
import '../providers/music_provider.dart';
import '../providers/post_provider.dart';
import '../services/music_service.dart';
import '../services/preview_player_service.dart';
import '../utils/meme_library.dart';
import '../widgets/vibe_card_view.dart';
import '../widgets/vibe_card_canvas.dart';

// screen for editing an existing vibe card
// loads the document from firestore, then updates or deletes it
class EditScreen extends ConsumerStatefulWidget {
  static const String routeName = '/edit';

  const EditScreen({super.key});

  @override
  ConsumerState<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<EditScreen> {
  static const Color _cardDark = Color(0xFF101018);
  static const Color _surface = Color(0xFF181827);
  static const Color _neonPurple = Color(0xFFBB86FC);
  static const Color _neonPink = Color(0xFFFF6EC7);
  static const Color _neonCyan = Color(0xFF03DAC6);
  static const Color _textPrimary = Color(0xFFF4F1FF);
  static const Color _textSecondary = Color(0xFF9B95B8);
  static const Color _border = Color(0xFF2E2448);
  static const Color _error = Color(0xFFFF6E8A);

  // caption is shown when the user presses save
  final GlobalKey<FormState> _captionFormKey = GlobalKey<FormState>();
  final TextEditingController _captionController = TextEditingController();

  // the card being edited, loaded from firestore in didChangeDependencies
  VibeCard? _card;
  bool _didStartLoading = false;
  bool _isLoading = true;
  String? _loadError;

  int _selectedSongIndex = 0;
  int _selectedMemeIndex = 0;
  int _selectedVibeIndex = 0;
  bool _isSaving = false;

  // preloaded artwork + preview clip for every song option
  Map<String, SongInfo> _songInfo = {};
  String? _playingUrl;
  StreamSubscription<PlayerState>? _playerSub;

  // held directly because ref cannot be used inside dispose()
  PreviewPlayerService? _player;

  String _songKey(int index) =>
      '${_songs[index]['name']}|${_songs[index]['artist']}'.toLowerCase();

  SongInfo _infoFor(int index) => _songInfo[_songKey(index)] ?? SongInfo.empty;

  // the artwork for whichever song is selected right now. the lookup wins
  // once it lands; until then the artwork already on the card is reused,
  // but only while the song itself has not been swapped for another one.
  String get _selectedAlbumArtUrl {
    final String? found = _infoFor(_selectedSongIndex).artworkUrl;

    if (found != null) {
      return found;
    }

    final VibeCard? card = _card;

    if (card == null) {
      return '';
    }

    final bool sameSong =
        (_songs[_selectedSongIndex]['name'] ?? '') == card.songName;

    return sameSong ? card.albumArtUrl : '';
  }

  // the card as it would be if the user saved right now: the stored card
  // with everything currently chosen in the panels applied on top.
  // the preview draws from this, which is what makes the card itself
  // change as the song, meme and vibe are picked.
  VibeCard? get _previewCard {
    final VibeCard? card = _card;

    if (card == null) {
      return null;
    }

    return card.copyWith(
      caption: _captionController.text.trim(),
      // the category is left exactly as the AI classified it
      vibeLabel: _currentLabel,
      vibeLabelOptions: _vibes,
      songOptions: _songs
          .map(
            (song) => {
              'name': song['name'] ?? '',
              'artist': song['artist'] ?? '',
            },
          )
          .toList(),
      memeOptions: _memes.map((meme) => meme['name'] ?? '').toList(),
      songName: _songs[_selectedSongIndex]['name'],
      songArtist: _songs[_selectedSongIndex]['artist'],
      memeName: _memes[_selectedMemeIndex]['name'],
      memeEmoji: _memes[_selectedMemeIndex]['emoji'],
      albumArtUrl: _selectedAlbumArtUrl,
    );
  }

  // WEB SERVICE - preloads all song covers and clips in parallel
  Future<void> _loadSongInfo() async {
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

  // plays the 30 second clip for the chosen song
  Future<void> _playPreview(int index) async {
    final String? url = _infoFor(index).previewUrl;

    if (url == null) return;

    final player = ref.read(previewPlayerProvider);
    await player.play(url);

    if (!mounted) return;

    setState(() {
      _playingUrl = player.currentUrl;
    });

    if (player.lastError != null) {
      _showAuraSnackBar(
        'Could not play the preview on this device.',
        icon: Icons.volume_off_rounded,
        color: _textSecondary,
      );
    }
  }

  bool _isDeleting = false;

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

  // stand-in only; the AI's own three picks replace these on load
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

  // the wordings the "Next vibe" button cycles through. the ones the AI
  // wrote for this card replace these on load; the list below stands in for
  // cards that were made before the AI offered alternatives, or when the
  // scan had failed and the card was posted with a fallback wording.
  List<String> _vibes = VibeCard.categories;

  // the wording printed on the card. the card's category is never changed
  // here: it is what the AI classified from the photos, and the feed's
  // vibe filter queries it.
  String get _currentLabel => _vibes[_selectedVibeIndex];

  @override
  void initState() {
    super.initState();

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

  // route arguments are only available here, not in initState
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didStartLoading) {
      return;
    }

    _didStartLoading = true;

    final Object? argument = ModalRoute.of(context)?.settings.arguments;
    final String postId = argument is String ? argument : '';

    _loadCard(postId);
  }

  // SELECT ONE - loads the card and fills the editor with its saved values
  Future<void> _loadCard(String postId) async {
    if (postId.isEmpty) {
      setState(() {
        _isLoading = false;
        _loadError = 'No vibe card was selected.';
      });
      return;
    }

    try {
      final VibeCard? card = await ref
          .read(firestoreServiceProvider)
          .selectOnePost(postId);

      if (!mounted) return;

      if (card == null) {
        setState(() {
          _isLoading = false;
          _loadError = 'This vibe card no longer exists.';
        });
        return;
      }

      setState(() {
        _card = card;
        _captionController.text = card.caption;

        // offer the songs the AI actually suggested for this card. the
        // list above is only a stand-in for cards made before those were
        // stored, or when the scan had failed.
        if (card.songOptions.isNotEmpty) {
          _songs = card.songOptions.map((song) {
            final String name = song['name'] ?? '';

            return {
              'name': name,
              'artist': song['artist'] ?? '',
              'vibe': 'AI pick',
              'short': name.isEmpty ? '?' : name[0].toUpperCase(),
            };
          }).toList();
        }

        // the saved values may have been generated by the AI, so they will
        // not appear in the default lists. add them as the first option
        // instead of silently replacing them with a default pick.
        final int songIndex = _songs.indexWhere(
          (song) => song['name'] == card.songName,
        );

        if (songIndex >= 0) {
          _selectedSongIndex = songIndex;
        } else if (card.songName.isNotEmpty) {
          _songs = [
            {
              'name': card.songName,
              'artist': card.songArtist,
              'vibe': 'saved pick',
              'short': card.songName[0].toUpperCase(),
            },
            ..._songs,
          ];
          _selectedSongIndex = 0;
        }

        // the three memes the AI picked for this card, resolved back through
        // the library so each one has real artwork
        if (card.memeOptions.isNotEmpty) {
          _memes = card.memeOptions.map((name) {
            final MemeOption option = MemeLibrary.byName(name);

            return {
              'name': option.name,
              'emoji': option.emoji,
              'match': option.expression,
              'image': option.imagePath,
            };
          }).toList();
        }

        final int memeIndex = _memes.indexWhere(
          (meme) => meme['name'] == card.memeName,
        );

        if (memeIndex >= 0) {
          _selectedMemeIndex = memeIndex;
        } else if (card.memeName.isNotEmpty) {
          _memes = [
            {
              'name': card.memeName,
              'emoji': card.memeEmoji,
              'match': 'saved pick',
              'image': MemeLibrary.imageFor(card.memeName),
            },
            ..._memes,
          ];
          _selectedMemeIndex = 0;
        }

        // offer the wordings the AI wrote for this card. the wording the
        // card is using goes first so it is always one of the options,
        // even if it was typed before the AI offered alternatives.
        if (card.vibeLabelOptions.isNotEmpty) {
          _vibes = card.vibeLabelOptions;
        }

        final String saved = card.displayVibe.trim();

        final int vibeIndex = _vibes.indexWhere(
          (v) => v.toLowerCase() == saved.toLowerCase(),
        );

        if (vibeIndex >= 0) {
          _selectedVibeIndex = vibeIndex;
        } else if (saved.isNotEmpty) {
          _vibes = [saved, ..._vibes];
          _selectedVibeIndex = 0;
        }

        _isLoading = false;
      });

      _loadSongInfo();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = ref.read(firestoreServiceProvider).getErrorMessage(error);
      });
    }
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player?.stop();
    _captionController.dispose();
    super.dispose();
  }

  // cycles to the next wording the AI offered for this card, wrapping back
  // round to the first one, so nothing is ever lost by pressing it
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

  // opens caption form before saving changes
  void _showSaveSheet() {
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
                  'Save Your Vibe Card',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Update your caption before saving this edited vibe card.',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _captionController,
                  maxLength: 150,
                  maxLines: 3,
                  style: const TextStyle(color: _textPrimary),
                  cursorColor: _neonPurple,
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
                      borderSide: const BorderSide(
                        color: _neonPurple,
                        width: 1.5,
                      ),
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
                      _saveVibeCard();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text(
                      'Save Vibe Card',
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

  // opens the caption form before saving the update
  // UPDATE - writes the edited values back to the same firestore document
  Future<void> _saveVibeCard() async {
    final VibeCard? card = _card;

    if (card == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // saving writes exactly what the preview has been showing, so the card
    // on the feed ends up looking like the card in the editor.
    // copyWith keeps postId, userId and createdAt exactly as they were.
    final VibeCard? updated = _previewCard;

    if (updated == null) {
      setState(() {
        _isSaving = false;
      });
      return;
    }

    try {
      await ref.read(firestoreServiceProvider).updatePost(updated);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showAuraSnackBar(
        'Vibe card saved',
        icon: Icons.check_circle_rounded,
        color: _neonCyan,
      );

      Navigator.of(context).pushReplacementNamed(ProfileScreen.routeName);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showAuraSnackBar(
        ref.read(firestoreServiceProvider).getErrorMessage(error),
        icon: Icons.error_outline_rounded,
        color: _error,
      );
    }
  }

  // confirms before deleting the card
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _neonPink.withValues(alpha: 0.35)),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: _neonPink, size: 23),
              SizedBox(width: 10),
              Text(
                'Delete Card?',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'This will permanently remove the vibe card from your profile '
            'and the feed. This cannot be undone.',
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textPrimary,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _deleteVibeCard();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neonPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: const Text(
                  'Delete Card',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // DELETE - removes the document from the posts collection
  Future<void> _deleteVibeCard() async {
    final VibeCard? card = _card;

    if (card == null) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await ref.read(firestoreServiceProvider).deletePost(card.postId);

      if (!mounted) return;

      setState(() {
        _isDeleting = false;
      });

      _showAuraSnackBar(
        'Vibe card deleted',
        icon: Icons.delete_outline_rounded,
        color: _neonPink,
      );

      Navigator.of(context).pushReplacementNamed(ProfileScreen.routeName);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
      });

      _showAuraSnackBar(
        ref.read(firestoreServiceProvider).getErrorMessage(error),
        icon: Icons.error_outline_rounded,
        color: _error,
      );
    }
  }

  // shows styled messages to the user
  void _showAuraSnackBar(
    String message, {
    IconData icon = Icons.info_outline_rounded,
    Color color = _neonPurple,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 18),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(child: _buildBody()),
    );
  }

  // shows a spinner while the document loads, then the editor panels
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _neonPurple));
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: _textSecondary,
                size: 44,
              ),
              const SizedBox(height: 14),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
      child: Column(
        children: [
          _buildVibeCardCanvas(),
          _buildArtworkNotice(),
          const SizedBox(height: 14),
          _buildMusicPanel(),
          const SizedBox(height: 12),
          _buildMemePanel(),
          const SizedBox(height: 12),
          _buildVibeLabelPanel(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // top bar with delete and save actions
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
        'Edit Your Vibe Card',
        overflow: TextOverflow.ellipsis,
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
            child: TextButton.icon(
              onPressed: _isSaving || _isDeleting
                  ? null
                  : _showDeleteConfirmation,
              style: TextButton.styleFrom(
                foregroundColor: _neonPink,
                backgroundColor: _neonPink.withValues(alpha: 0.10),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: _neonPink.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                ),
              ),
              icon: _isDeleting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: _neonPink,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text(
                'Delete',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Center(
          child: SizedBox(
            height: 44,
            child: TextButton(
              onPressed: _isSaving || _isDeleting ? null : _showSaveSheet,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _neonPurple,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: _neonPink.withValues(alpha: 0.65),
                    width: 1.2,
                  ),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // older cards were saved as one flat picture, so there are no parts to
  // redraw and only their details can change. this explains that.
  // cards that can be composed need no notice: their preview just updates.
  Widget _buildArtworkNotice() {
    final VibeCard? card = _card;

    if (card == null || card.isLiveComposed) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _neonCyan.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: _neonCyan, size: 15),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'The artwork is final once posted. Edits below update the '
              'card details, not the picture.',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // shows the card as it will be once saved. the card is composed from its
  // parts rather than stored as a flat picture, so changing the song, the
  // meme or the vibe updates this preview straight away.
  Widget _buildVibeCardCanvas() {
    final VibeCard? card = _previewCard;

    return AspectRatio(
      aspectRatio: VibeCardCanvas.aspect,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _neonPurple.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: _neonPurple.withValues(alpha: 0.20),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: card == null
              ? Container(color: _cardDark)
              : VibeCardView(card: card, fit: BoxFit.cover),
        ),
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
        border: Border.all(color: _neonPurple.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(color: _neonPurple.withValues(alpha: 0.10), blurRadius: 16),
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
          separatorBuilder: (context, index) {
            return const SizedBox(width: 10);
          },
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
                  color: selected
                      ? _neonPurple.withValues(alpha: 0.13)
                      : _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? _neonPurple : _border,
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

  // album cover plus a play / pause badge showing which clip is running
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
          border: Border.all(color: _neonPurple.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                // whatever the card chip is showing, so this panel and the
                // preview above it never disagree
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
