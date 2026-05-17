import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../models/flashcard.dart';
import '../models/flashcard_set.dart';
import '../providers/home_provider.dart';
import '../services/gemini_service.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/flashcard_tile.dart';
import 'study_screen.dart';
import 'saved_sets_screen.dart';

const _languages = [
  ('English', '🇬🇧'), ('Slovak', '🇸🇰'), ('Czech', '🇨🇿'),
  ('German', '🇩🇪'), ('Spanish', '🇪🇸'), ('French', '🇫🇷'),
  ('Italian', '🇮🇹'), ('Polish', '🇵🇱'), ('Hungarian', '🇭🇺'), ('Portuguese', '🇵🇹'),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _imagePicker = ImagePicker();

  // ── File picking ────────────────────────────────────────────

  Future<void> _pickFile(HomeProvider p) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'csv', 'pdf', 'docx', 'pptx'],
      withData: true, allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    p.setExtracting(true);
    p.setError(null);

    try {
      final buffer = StringBuffer();
      final names = <String>[];
      for (final file in result.files) {
        if (file.bytes == null) continue;
        final text = await FileService.extractText(bytes: file.bytes!, fileName: file.name);
        buffer.writeln('=== ${file.name} ===');
        buffer.writeln(text);
        buffer.writeln();
        names.add(file.name);
      }
      p.setFile(
        name: names.length == 1 ? names.first : '${names.length} files selected',
        size: result.files.fold<int>(0, (sum, f) => sum + (f.size ?? 0)),
        content: buffer.toString(),
      );
    } on UnsupportedFileException catch (e) {
      p.setError(e.message);
    } catch (_) {
      p.setError('Could not read one or more files.');
    } finally {
      p.setExtracting(false);
    }
  }

  // ── Image picking ────────────────────────────────────────────

  Future<void> _pickImages(HomeProvider p, ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final picked = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2048, maxHeight: 2048);
        if (picked == null) return;
        if (p.imageBytes.length >= 10) { p.setError('Maximum 10 photos allowed.'); return; }
        final bytes = await picked.readAsBytes();
        p.addImages([bytes], ['Photo ${p.imageBytes.length + 1}']);
      } else {
        final remaining = 10 - p.imageBytes.length;
        if (remaining <= 0) { p.setError('Maximum 10 photos allowed.'); return; }
        final picked = await _imagePicker.pickMultiImage(imageQuality: 85, maxWidth: 2048, maxHeight: 2048);
        if (picked.isEmpty) return;
        final toAdd = picked.take(remaining).toList();
        final newBytes = await Future.wait(toAdd.map((f) => f.readAsBytes()));
        p.addImages(newBytes, toAdd.map((f) => f.name).toList());
        if (picked.length > remaining) p.setError('Only $remaining more photos could be added (max 10).');
      }
    } catch (_) { p.setError('Could not load image.'); }
  }

  void _showImageSourceSheet(HomeProvider p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1928),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(p.imageBytes.isEmpty ? 'Add photos' : 'Add more (${p.imageBytes.length}/10)',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _ImageSourceButton(emoji: '📷', label: 'Camera', onTap: () { Navigator.pop(context); _pickImages(p, ImageSource.camera); })),
            const SizedBox(width: 12),
            Expanded(child: _ImageSourceButton(emoji: '🖼️', label: 'Gallery', onTap: () { Navigator.pop(context); _pickImages(p, ImageSource.gallery); })),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Generation ──────────────────────────────────────────────

  Future<void> _generate(HomeProvider p) async {
    if (!p.hasInput) return;
    p.setLoading(true);
    p.setError(null);
    p.setCards([]);

    try {
      final cards = p.hasImages
          ? await GeminiService.generateFlashcardsFromImages(p.imageBytes, count: p.cardCount, language: p.language)
          : await GeminiService.generateFlashcards(p.fileContent!, count: p.cardCount, language: p.language);

      if (cards.isEmpty) {
        p.setError('No study material found. Try a clearer photo.');
      } else {
        p.setCards(cards);
      }
    } on GeminiException catch (e) {
      p.setError('API error: ${e.message}');
    } catch (_) {
      p.setError("Couldn't generate flashcards. Try again.");
    } finally {
      p.setLoading(false);
    }
  }

  // ── Save set ─────────────────────────────────────────────────

  Future<void> _saveSet(HomeProvider p) async {
    String name = p.fileName ?? 'My Set';
    if (name.contains('.')) name = name.substring(0, name.lastIndexOf('.'));

    final controller = TextEditingController(text: name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Save set', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Set name', hintStyle: const TextStyle(color: AppColors.muted),
            filled: true, fillColor: const Color(0xFF252340),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.muted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700))),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      final set = FlashcardSet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: controller.text.trim(),
        createdAt: DateTime.now(),
        cards: p.cards,
      );
      await StorageService.saveSet(set);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅  "${set.name}" saved!'),
          backgroundColor: AppColors.cardBg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = context.watch<HomeProvider>();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(bottom: isLandscape ? 20 : 40),
          children: [
            _Header(
              onSavedSets: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedSetsScreen())),
              onLogout: () async => await AuthService.logout(),
            ),
            SizedBox(height: isLandscape ? 12 : 24),

            isLandscape
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 200,
                        child: Column(children: [
                          _UploadZone(onTap: p.extracting ? null : () => _pickFile(p)),
                          const SizedBox(height: 10),
                          _CameraButton(onTap: p.extracting ? null : () => _showImageSourceSheet(p)),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(children: [
                        _CardCountPicker(value: p.cardCount, onChanged: p.setCardCount),
                        const SizedBox(height: 10),
                        _LanguagePicker(value: p.language, onChanged: p.setLanguage),
                      ])),
                    ]),
                  )
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        Expanded(child: _UploadZone(onTap: p.extracting ? null : () => _pickFile(p))),
                        const SizedBox(width: 12),
                        _CameraButton(onTap: p.extracting ? null : () => _showImageSourceSheet(p)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    _CardCountPicker(value: p.cardCount, onChanged: p.setCardCount),
                    const SizedBox(height: 10),
                    _LanguagePicker(value: p.language, onChanged: p.setLanguage),
                  ]),

            if (p.extracting) ...[const SizedBox(height: 14), const _ExtractingState()],
            if (p.hasImages) ...[const SizedBox(height: 14), _ImageGrid(provider: p)],
            if (p.hasFile && !p.extracting) ...[
              const SizedBox(height: 14),
              _FileInfo(name: p.fileName!, sizeKb: ((p.fileSize ?? 0) / 1024).toStringAsFixed(1), onRemove: p.clearAll),
            ],
            if (p.error != null) ...[const SizedBox(height: 14), _ErrorBanner(message: p.error!)],
            if (p.hasInput && !p.loading && !p.extracting) ...[
              const SizedBox(height: 16),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GradientButton(label: '✨  Generate Flashcards', onTap: () => _generate(p))),
            ],
            if (p.loading) ...[const SizedBox(height: 48), const _LoadingState()],
            if (p.cards.isNotEmpty) ...[
              const SizedBox(height: 28),
              _CardsHeader(count: p.cards.length, onSave: () => _saveSet(p)),
              const SizedBox(height: 4),
              if (isLandscape)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _TwoColumnCards(cards: p.cards),
                )
              else
                ...p.cards.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: FlashcardTile(card: e.value, index: e.key),
                    )),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: OutlineButton(
                  label: '🚀  Start Study Mode',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudyScreen(cards: p.cards))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Two column cards for landscape ────────────────────────────

class _TwoColumnCards extends StatelessWidget {
  final List<Flashcard> cards;
  const _TwoColumnCards({required this.cards});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < cards.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: FlashcardTile(card: cards[i], index: i)),
          const SizedBox(width: 12),
          i + 1 < cards.length
              ? Expanded(child: FlashcardTile(card: cards[i + 1], index: i + 1))
              : const Expanded(child: SizedBox()),
        ]),
      ));
    }
    return Column(children: rows);
  }
}

// ── Widgets ────────────────────────────────────────────────────

class _CardCountPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _CardCountPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Number of cards', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: AppColors.gradient),
            child: Text('$value', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8), overlayShape: const RoundSliderOverlayShape(overlayRadius: 16)),
          child: Slider(value: value.toDouble(), min: 5, max: 20, divisions: 15, activeColor: AppColors.accent, inactiveColor: AppColors.cardBorder, onChanged: (v) => onChanged(v.round())),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('5 cards', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            Text('20 cards', style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
        ),
      ]),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _LanguagePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        const Text('Language', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        const Spacer(),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value, dropdownColor: const Color(0xFF1E1D30),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.muted, size: 20),
            style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Roboto'),
            items: _languages.map((lang) => DropdownMenuItem<String>(
              value: lang.$1,
              child: Row(children: [Text(lang.$2, style: const TextStyle(fontSize: 18)), const SizedBox(width: 10), Text(lang.$1, style: const TextStyle(color: Colors.white, fontSize: 14))]),
            )).toList(),
            onChanged: (val) { if (val != null) onChanged(val); },
            selectedItemBuilder: (context) => _languages.map((lang) => Row(children: [
              Text(lang.$2, style: const TextStyle(fontSize: 18)), const SizedBox(width: 8),
              Text(lang.$1, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ])).toList(),
          ),
        ),
      ]),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  final HomeProvider provider;
  const _ImageGrid({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.accentPink)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('📷', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text('${provider.imageBytes.length} photo${provider.imageBytes.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          const Spacer(),
          if (provider.imageBytes.length < 10)
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF1A1928),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 20),
                      const Text('Add more photos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(child: _ImageSourceButton(emoji: '📷', label: 'Camera', onTap: () async {
                          Navigator.pop(context);
                          final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2048, maxHeight: 2048);
                          if (picked != null) { final b = await picked.readAsBytes(); provider.addImages([b], [picked.name]); }
                        })),
                        const SizedBox(width: 12),
                        Expanded(child: _ImageSourceButton(emoji: '🖼️', label: 'Gallery', onTap: () async {
                          Navigator.pop(context);
                          final remaining = 10 - provider.imageBytes.length;
                          final picked = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 2048, maxHeight: 2048);
                          if (picked.isEmpty) return;
                          final toAdd = picked.take(remaining).toList();
                          final bytes = await Future.wait(toAdd.map((f) => f.readAsBytes()));
                          provider.addImages(bytes, toAdd.map((f) => f.name).toList());
                        })),
                      ]),
                      const SizedBox(height: 8),
                    ]),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.accentPink)),
                child: const Text('+ Add', style: TextStyle(fontSize: 12, color: AppColors.accentPink, fontWeight: FontWeight.w600)),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(onTap: provider.clearAll, child: const Text('✕', style: TextStyle(fontSize: 18, color: AppColors.muted))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: provider.imageBytes.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(children: [
                Container(width: 80, height: 80,
                    decoration: BoxDecoration(color: const Color(0xFF252340), borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(image: MemoryImage(provider.imageBytes[i]), fit: BoxFit.cover))),
                Positioned(top: 4, right: 4,
                  child: GestureDetector(onTap: () => provider.removeImage(i),
                    child: Container(width: 20, height: 20,
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle),
                        child: const Center(child: Text('✕', style: TextStyle(fontSize: 10, color: Colors.white))))),
                ),
                Positioned(bottom: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(4)),
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onSavedSets;
  final VoidCallback onLogout;
  const _Header({required this.onSavedSets, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.asset('assets/icon/icon.png', width: 42, height: 42, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('FlashAI', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
          Text('Study smarter with AI', style: TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
        const Spacer(),
        Row(children: [
          GestureDetector(
            onTap: onSavedSets,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
              child: const Row(children: [
                Text('📚', style: TextStyle(fontSize: 16)), SizedBox(width: 6),
                Text('Saved', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onLogout,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
              child: const Text('🚪', style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _UploadZone extends StatelessWidget {
  final VoidCallback? onTap;
  const _UploadZone({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder, width: 1.5)),
        child: Column(children: [
          const Text('📄', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          const Text('Upload file', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('PDF · DOCX · PPTX\nTXT · MD · CSV', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.muted, height: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: AppColors.gradient),
            child: const Text('Browse', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _CameraButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.accentPink, width: 1.5)),
        child: Column(children: [
          const Text('📷', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          const Text('Photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Camera\nor Gallery', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.muted, height: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(colors: [Color(0xFFFF6584), Color(0xFFFF8C69)])),
            child: const Text('Snap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}

class _ImageSourceButton extends StatelessWidget {
  final String emoji, label;
  final VoidCallback onTap;
  const _ImageSourceButton({required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: const Color(0xFF252340), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      ),
    );
  }
}

class _FileInfo extends StatelessWidget {
  final String name, sizeKb;
  final VoidCallback onRemove;
  const _FileInfo({required this.name, required this.sizeKb, required this.onRemove});

  String get _emoji {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return '📕'; case 'docx': return '📘';
      case 'pptx': return '📙'; case 'csv': return '📊'; default: return '📝';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF252340), borderRadius: BorderRadius.circular(11)), child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 22)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white), overflow: TextOverflow.ellipsis),
          Text('$sizeKb KB', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ])),
        GestureDetector(onTap: onRemove, child: const Padding(padding: EdgeInsets.only(left: 8), child: Text('✕', style: TextStyle(fontSize: 18, color: AppColors.muted)))),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.dangerBorder)),
      child: Text('⚠️  $message', style: const TextStyle(color: AppColors.danger, fontSize: 13)),
    );
  }
}

class _ExtractingState extends StatelessWidget {
  const _ExtractingState();
  @override
  Widget build(BuildContext context) => const Column(children: [
    CircularProgressIndicator(), SizedBox(height: 14),
    Text('Reading your file…', style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: FontWeight.w500)),
  ]);
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Column(children: [
    CircularProgressIndicator(), SizedBox(height: 18),
    Text('AI is reading your material…', style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: FontWeight.w500)),
  ]);
}

class _CardsHeader extends StatelessWidget {
  final int count;
  final VoidCallback onSave;
  const _CardsHeader({required this.count, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Your Flashcards', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
        Row(children: [
          GestureDetector(
            onTap: onSave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: AppColors.gradient),
              child: const Row(children: [
                Text('💾', style: TextStyle(fontSize: 13)), SizedBox(width: 4),
                Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
            child: Text('$count cards', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ]),
      ]),
    );
  }
}