import 'package:shared_preferences/shared_preferences.dart';
import '../models/flashcard_set.dart';

class StorageService {
  StorageService._();

  static const _setsKey = 'flashcard_sets';

  // ── Load all sets ────────────────────────────────────────────

  static Future<List<FlashcardSet>> loadSets() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_setsKey) ?? [];
    final sets = <FlashcardSet>[];

    for (final id in ids) {
      final json = prefs.getString('set_$id');
      if (json != null) {
        try {
          sets.add(FlashcardSet.fromJsonString(json));
        } catch (_) {}
      }
    }

    // Sort by newest first
    sets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sets;
  }

  // ── Save a set ───────────────────────────────────────────────

  static Future<void> saveSet(FlashcardSet set) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_setsKey) ?? [];

    if (!ids.contains(set.id)) {
      ids.add(set.id);
      await prefs.setStringList(_setsKey, ids);
    }

    await prefs.setString('set_${set.id}', set.toJsonString());
  }

  // ── Update a set (e.g. after spaced repetition changes) ──────

  static Future<void> updateSet(FlashcardSet set) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('set_${set.id}', set.toJsonString());
  }

  // ── Delete a set ─────────────────────────────────────────────

  static Future<void> deleteSet(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_setsKey) ?? [];
    ids.remove(id);
    await prefs.setStringList(_setsKey, ids);
    await prefs.remove('set_$id');
  }
}
