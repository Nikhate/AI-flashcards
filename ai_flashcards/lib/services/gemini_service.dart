import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/flashcard.dart';

class GeminiService {
  GeminiService._();

  // 🔒 Your Vercel server — API key is safe on the server!
  static const _serverUrl = 'https://flashcard-server-kohl.vercel.app/api/generate';

  // ── Text-based ───────────────────────────────────────────────

  static Future<List<Flashcard>> generateFlashcards(
    String content, {
    int count = 8,
    String language = 'English',
  }) async {
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _buildTextPrompt(content, count, language)},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 8192},
    });

    final response = await http.post(
      Uri.parse(_serverUrl),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw GeminiException('API returned ${response.statusCode}', details: response.body);
    }

    return _parseResponse(response.body);
  }

  // ── Image-based ──────────────────────────────────────────────

  static Future<List<Flashcard>> generateFlashcardsFromImages(
    List<Uint8List> images, {
    int count = 8,
    String language = 'English',
  }) async {
    final parts = <Map<String, dynamic>>[];

    for (final imageBytes in images) {
      parts.add({
        'inline_data': {
          'mime_type': 'image/jpeg',
          'data': base64Encode(imageBytes),
        }
      });
    }

    parts.add({'text': _buildImagePrompt(images.length, count, language)});

    final body = jsonEncode({
      'contents': [
        {'parts': parts},
      ],
      'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 8192},
    });

    final response = await http.post(
      Uri.parse(_serverUrl),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw GeminiException('API returned ${response.statusCode}', details: response.body);
    }

    return _parseResponse(response.body);
  }

  // ── Prompts ──────────────────────────────────────────────────

  static String _buildTextPrompt(String content, int count, String language) => '''
You are a flashcard generator. Read the learning material below and generate exactly $count high-quality flashcards.

Return ONLY a raw JSON array — no markdown fences, no explanation, just the JSON.
Format:
[{"question": "...", "answer": "..."}, ...]

Rules:
- Write ALL questions and answers in $language
- Questions should test key concepts, definitions, and understanding
- Answers should be concise but complete (2-4 sentences)
- Do not number the questions

Learning material:
${content.length > 8000 ? content.substring(0, 8000) : content}
''';

  static String _buildImagePrompt(int imageCount, int count, String language) => '''
Look at ${imageCount == 1 ? 'this image' : 'these $imageCount images'} of study notes (handwritten or printed).
Extract all the text, formulas, diagrams, and key information you can see across all images, then generate exactly $count high-quality flashcards from that content.

Return ONLY a raw JSON array — no markdown fences, no explanation, just the JSON.
Format:
[{"question": "...", "answer": "..."}, ...]

Rules:
- Write ALL questions and answers in $language
- Questions should test key concepts, definitions, and understanding
- Answers should be concise but complete (2-4 sentences)
- Do not number the questions
- If the images contain no study material, return an empty array: []
''';

  // ── Parser ───────────────────────────────────────────────────

  static List<Flashcard> _parseResponse(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final raw = (data['candidates'] as List).first['content']['parts'].first['text'] as String;
    final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    final list = jsonDecode(clean) as List<dynamic>;
    return list.map((e) => Flashcard.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class GeminiException implements Exception {
  final String message;
  final String? details;
  const GeminiException(this.message, {this.details});

  @override
  String toString() => 'GeminiException: $message${details != null ? '\n$details' : ''}';
}