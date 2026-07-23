class PollModel {
  final String question;
  final List<PollOption> options;
  final bool allowMultiple;
  final DateTime? expiresAt;

  PollModel({
    required this.question,
    required this.options,
    this.allowMultiple = false,
    this.expiresAt,
  });

  factory PollModel.fromJson(Map<String, dynamic> json) => PollModel(
        question: json['question'] as String? ?? '',
        options: (json['options'] as List? ?? [])
            .map((o) => PollOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        allowMultiple: json['allowMultiple'] as bool? ?? false,
        expiresAt: json['expiresAt'] != null
            ? DateTime.tryParse(json['expiresAt'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options.map((o) => o.toJson()).toList(),
        'allowMultiple': allowMultiple,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      };

  int get totalVotes => options.fold(0, (sum, o) => sum + o.votes.length);
}

class PollOption {
  final String text;
  final List<String> votes; // list of uids who voted

  PollOption({required this.text, this.votes = const []});

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
        text: json['text'] as String? ?? '',
        votes: List<String>.from(json['votes'] as List? ?? []),
      );

  Map<String, dynamic> toJson() => {'text': text, 'votes': votes};
}
