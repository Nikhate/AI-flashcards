import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flashcard_set.dart';

class StorageService {
  StorageService._();

  static final _db = FirebaseFirestore.instance;

  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference get _setsRef =>
      _db.collection('users').doc(_userId).collection('sets');

  // ── Load all sets ────────────────────────────────────────────

  static Future<List<FlashcardSet>> loadSets() async {
    if (_userId == null) return [];

    final snapshot = await _setsRef.orderBy('createdAt', descending: true).get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return FlashcardSet.fromJson(data);
    }).toList();
  }

  // ── Save a set ───────────────────────────────────────────────

  static Future<void> saveSet(FlashcardSet set) async {
    if (_userId == null) return;
    await _setsRef.doc(set.id).set(set.toJson());
  }

  // ── Update a set ─────────────────────────────────────────────

  static Future<void> updateSet(FlashcardSet set) async {
    if (_userId == null) return;
    await _setsRef.doc(set.id).set(set.toJson());
  }

  // ── Delete a set ─────────────────────────────────────────────

  static Future<void> deleteSet(String id) async {
    if (_userId == null) return;
    await _setsRef.doc(id).delete();
  }
}