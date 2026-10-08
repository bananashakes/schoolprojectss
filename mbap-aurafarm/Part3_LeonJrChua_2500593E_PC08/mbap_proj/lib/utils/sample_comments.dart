// sample comments shown on the seeded demo cards.
//
// comments are not part of the graded CRUD set (the spec allows only one,
// and that is the posts collection), so these are static sample data
// rather than a second firestore collection. cards the user creates start
// with no comments and show an empty state instead, so the count shown on
// a card always matches what is actually listed under it.
class SampleComment {
  final String username;
  final String text;
  final String likes;

  // avatar asset for this commenter. the file does not have to exist yet:
  // the UI falls back to a coloured initial when it is missing.
  final String avatarPath;

  const SampleComment({
    required this.username,
    required this.text,
    required this.likes,
    required this.avatarPath,
  });
}

class SampleComments {
  static const List<SampleComment> all = [
    SampleComment(
      username: 'luv.naaz',
      text: 'this vibe is crazyy!',
      likes: '24',
      avatarPath: 'images/avatars/avatar_1.png',
    ),
    SampleComment(
      username: 'Rachi',
      text: 'nahhh ts fits so well',
      likes: '90',
      avatarPath: 'images/avatars/avatar_2.png',
    ),
    SampleComment(
      username: 'Ami',
      text: 'i love the meme',
      likes: '200',
      avatarPath: 'images/avatars/avatar_3.png',
    ),
    SampleComment(
      username: 'lamonade',
      text: 'deep thinker core fr',
      likes: '63',
      avatarPath: 'images/avatars/avatar_4.png',
    ),
  ];

  // the seeded cards store this as their comment count, so the number on
  // the card matches the number of comments listed
  static int get count => all.length;

  // stable colour per username, used by the initial-letter fallback
  static int colorSeed(String username) {
    if (username.isEmpty) return 0;

    return username.codeUnits.fold<int>(0, (sum, c) => sum + c);
  }
}
