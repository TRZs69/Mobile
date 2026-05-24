class Assessment {
  final int id;
  final int chapterId;
  final String instruction;
  final List<Question> questions;
  List<String>? answers;
  final DateTime createdAt;
  final DateTime updatedAt;

  Assessment(
      {required this.id,
      required this.chapterId,
      required this.instruction,
      required this.questions,
      required this.answers,
      required this.createdAt,
      required this.updatedAt});

  factory Assessment.fromJson(Map<String, dynamic> json) {
    return Assessment(
      id: json['id'],
      chapterId: json['chapterId'],
      instruction: json['instruction'],
      questions: json['questions'],
      answers: json['answers'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class Question {
  int? id;
  String question;
  List<String> option;
  String correctedAnswer;
  String type;
  int elo;
  int? servedOrder;
  String selectedAnswer = '';
  int score = 0;
  List<String> selectedMultiAnswer = [];
  bool isCorrect = false;

  Question({
    this.id,
    required this.question,
    required this.option,
    required this.correctedAnswer,
    required this.type,
    this.elo = 1200,
    this.servedOrder,
  });

  factory Question.fromJson(Map<String, dynamic> map) {
    final optionsRaw = map['options'] ?? map['option'];
    final options = optionsRaw is List
        ? optionsRaw.map((e) => e.toString()).toList()
        : <String>[];

    final q = Question(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      question: (map['question'] ?? '').toString(),
      option: options,
      correctedAnswer:
          (map['correctedAnswer'] ?? map['answer'] ?? '').toString(),
      type: (map['type'] ?? 'MC').toString(),
      elo: map['elo'] is int
          ? map['elo'] as int
          : int.tryParse('${map['elo']}') ?? 1200,
      servedOrder: map['servedOrder'] is int ? map['servedOrder'] as int : null,
    );

    final submitted = (map['submittedAnswer'] ?? '').toString();
    if (submitted.isNotEmpty) {
      q.selectedAnswer = submitted;
    }
    q.isCorrect = map['isCorrect'] == true;
    q.score = map['score'] is int ? map['score'] as int : 0;

    return q;
  }
}
