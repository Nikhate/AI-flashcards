import 'dart:convert';
import 'flashcard.dart';

class FlashcardSet {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<Flashcard> cards;

  FlashcardSet({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.cards,
  });

  factory FlashcardSet.fromJson(Map<String, dynamic> json) => FlashcardSet(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        cards: (json['cards'] as List)
            .map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'cards': cards.map((c) => c.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  static FlashcardSet fromJsonString(String s) =>
      FlashcardSet.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
