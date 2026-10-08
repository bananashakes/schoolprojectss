// the meme library the AI picks from.
// the Part 1 proposal describes memes as being "selected from a library
// stored in the database", so the AI is constrained to these entries
// instead of inventing names we have no artwork for.
class MemeOption {
  final String name;
  final String imagePath;
  final String expression; // the facial expression this meme matches
  final String emoji; // small fallback used in compact list rows

  const MemeOption({
    required this.name,
    required this.imagePath,
    required this.expression,
    required this.emoji,
  });
}

class MemeLibrary {
  // the order matters in one place: byName falls back to the first entry
  // when a card refers to a meme that is no longer here.
  static const List<MemeOption> all = [
    MemeOption(
      name: 'Cat Stare',
      imagePath: 'images/memes/cat_stare.png',
      expression: 'unimpressed or judging',
      emoji: '🐈',
    ),
    MemeOption(
      name: 'Huh',
      imagePath: 'images/memes/huh.png',
      expression: 'confused or thinking it over',
      emoji: '🐵',
    ),
    MemeOption(
      name: 'Devious',
      imagePath: 'images/memes/devious.png',
      expression: 'scheming or up to something',
      emoji: '😈',
    ),
    MemeOption(
      name: 'Nerd',
      imagePath: 'images/memes/nerd.png',
      expression: 'smug or know-it-all',
      emoji: '🤓',
    ),
    MemeOption(
      name: 'Goofy',
      imagePath: 'images/memes/goofy.png',
      expression: 'loud and excited',
      emoji: '😆',
    ),
    MemeOption(
      name: 'Derp',
      imagePath: 'images/memes/derp.png',
      expression: 'silly or chaotic',
      emoji: '😛',
    ),
    MemeOption(
      name: 'Rage',
      imagePath: 'images/memes/rage.png',
      expression: 'angry or fed up',
      emoji: '😡',
    ),
    MemeOption(
      name: 'Defeated',
      imagePath: 'images/memes/defeated.png',
      expression: 'tired or done with life',
      emoji: '😩',
    ),
  ];

  // name plus the mood it represents, injected into the AI prompt so the
  // model can match a face to the right meme instead of guessing from the
  // name alone
  static String get namesForPrompt => all
      .map(
        (meme) =>
            '- "${meme.name}" — use when the face reads ${meme.expression}',
      )
      .join('\n');

  // finds a library entry by name, falling back to the first one so the
  // card always has artwork even if the AI returns something unexpected
  static MemeOption byName(String name) {
    for (final MemeOption meme in all) {
      if (meme.name.toLowerCase() == name.toLowerCase()) {
        return meme;
      }
    }

    return all.first;
  }

  // resolves an image path for a stored meme name
  static String imageFor(String name) => byName(name).imagePath;
}
