class Me {
  final int id;
  final String name;
  final List<String> likedTags;
  final bool paired;

  const Me(
      {required this.id,
      required this.name,
      required this.likedTags,
      required this.paired});

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        id: j['id'] as int,
        name: j['name'] as String,
        likedTags: List<String>.from(j['liked_tags'] as List),
        paired: j['paired'] as bool,
      );
}

class CoupleInfo {
  final String inviteCode;
  final String? partnerName;
  final int streak;

  const CoupleInfo(
      {required this.inviteCode, this.partnerName, required this.streak});

  bool get complete => partnerName != null;

  factory CoupleInfo.fromJson(Map<String, dynamic> j) => CoupleInfo(
        inviteCode: j['invite_code'] as String,
        partnerName: j['partner_name'] as String?,
        streak: j['streak'] as int,
      );
}

class Question {
  final String id;
  final String tag;
  final String prompt;
  final String a;
  final String b;

  const Question({
    required this.id,
    required this.tag,
    required this.prompt,
    required this.a,
    required this.b,
  });

  String label(String choice) => choice == 'a' ? a : b;

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        tag: j['tag'] as String,
        prompt: j['prompt'] as String,
        a: j['a'] as String,
        b: j['b'] as String,
      );
}

class TodayGame {
  final String day;
  final List<Question> questions;
  final bool iAnswered;
  final bool partnerAnswered;

  const TodayGame({
    required this.day,
    required this.questions,
    required this.iAnswered,
    required this.partnerAnswered,
  });

  factory TodayGame.fromJson(Map<String, dynamic> j) => TodayGame(
        day: j['day'] as String,
        questions: (j['questions'] as List)
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList(),
        iAnswered: j['i_answered'] as bool,
        partnerAnswered: j['partner_answered'] as bool,
      );
}

/// One question's answers from me: what I picked, and what I think they picked.
class MyAnswer {
  final String mine;
  final String guess;
  const MyAnswer(this.mine, this.guess);

  Map<String, dynamic> toJson(String questionId) =>
      {'question_id': questionId, 'mine': mine, 'guess': guess};
}

class RevealItem {
  final Question question;
  final String myPick;
  final String partnerPick;
  final bool iGuessedRight;
  final bool partnerGuessedRight;

  const RevealItem({
    required this.question,
    required this.myPick,
    required this.partnerPick,
    required this.iGuessedRight,
    required this.partnerGuessedRight,
  });

  factory RevealItem.fromJson(Map<String, dynamic> j) => RevealItem(
        question: Question.fromJson(j['question'] as Map<String, dynamic>),
        myPick: j['my_pick'] as String,
        partnerPick: j['partner_pick'] as String,
        iGuessedRight: j['i_guessed_right'] as bool,
        partnerGuessedRight: j['partner_guessed_right'] as bool,
      );
}

enum ResultState { waitingForMe, waitingForPartner, ready }

class GameResult {
  final ResultState state;
  final int? score;
  final int? outOf;
  final int? samePicks;
  final List<RevealItem> items;
  final int streak;

  const GameResult({
    required this.state,
    this.score,
    this.outOf,
    this.samePicks,
    this.items = const [],
    this.streak = 0,
  });

  factory GameResult.fromJson(Map<String, dynamic> j) => GameResult(
        state: switch (j['state']) {
          'waiting_for_me' => ResultState.waitingForMe,
          'waiting_for_partner' => ResultState.waitingForPartner,
          'ready' => ResultState.ready,
          final s => throw FormatException('unknown result state: $s'),
        },
        score: j['score'] as int?,
        outOf: j['out_of'] as int?,
        samePicks: j['same_picks'] as int?,
        items: ((j['items'] as List?) ?? const [])
            .map((i) => RevealItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        streak: (j['streak'] as int?) ?? 0,
      );
}
