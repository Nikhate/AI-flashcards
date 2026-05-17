class Flashcard {
  final String question;
  final String answer;
  int timesWrong; // for spaced repetition

  Flashcard({
    required this.question,
    required this.answer,
    this.timesWrong = 0,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        question: json['question'] as String,
        answer: json['answer'] as String,
        timesWrong: json['timesWrong'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'timesWrong': timesWrong,
      };
}