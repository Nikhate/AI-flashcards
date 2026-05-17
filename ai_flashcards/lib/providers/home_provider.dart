import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/flashcard.dart';

class HomeProvider extends ChangeNotifier {
  // File mode
  String? fileName;
  String? fileContent;
  int? fileSize;

  // Image mode
  List<Uint8List> imageBytes = [];
  List<String> imageNames = [];

  // Cards
  List<Flashcard> cards = [];

  // State
  bool loading = false;
  bool extracting = false;
  String? error;
  int cardCount = 8;
  String language = 'English';

  bool get hasFile => fileContent != null;
  bool get hasImages => imageBytes.isNotEmpty;
  bool get hasInput => hasFile || hasImages;

  void setLoading(bool val) { loading = val; notifyListeners(); }
  void setExtracting(bool val) { extracting = val; notifyListeners(); }
  void setError(String? val) { error = val; notifyListeners(); }
  void setCards(List<Flashcard> val) { cards = val; notifyListeners(); }
  void setCardCount(int val) { cardCount = val; notifyListeners(); }
  void setLanguage(String val) { language = val; notifyListeners(); }

  void setFile({required String name, required int size, required String content}) {
    fileName = name;
    fileSize = size;
    fileContent = content;
    imageBytes = [];
    imageNames = [];
    cards = [];
    error = null;
    notifyListeners();
  }

  void addImages(List<Uint8List> bytes, List<String> names) {
    imageBytes.addAll(bytes);
    imageNames.addAll(names);
    fileContent = null;
    fileName = null;
    cards = [];
    error = null;
    notifyListeners();
  }

  void removeImage(int index) {
    imageBytes.removeAt(index);
    imageNames.removeAt(index);
    if (imageBytes.isEmpty) cards = [];
    notifyListeners();
  }

  void clearAll() {
    fileName = null; fileContent = null; fileSize = null;
    imageBytes = []; imageNames = [];
    cards = []; error = null;
    notifyListeners();
  }
}
