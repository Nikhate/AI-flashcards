import 'package:flutter/material.dart';
import '../models/flashcard_set.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'study_screen.dart';

class SavedSetsScreen extends StatefulWidget {
  const SavedSetsScreen({super.key});

  @override
  State<SavedSetsScreen> createState() => _SavedSetsScreenState();
}

class _SavedSetsScreenState extends State<SavedSetsScreen> {
  List<FlashcardSet> _sets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sets = await StorageService.loadSets();
    setState(() { _sets = sets; _loading = false; });
  }

  Future<void> _delete(FlashcardSet set) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete set?', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${set.name}"?', style: const TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.muted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.deleteSet(set.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Text('← Back', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 14),
              const Text('Saved Sets', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
              const Spacer(),
              Text('${_sets.length} sets', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          const SizedBox(height: 20),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _sets.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        itemCount: _sets.length,
                        itemBuilder: (context, i) => _SetTile(
                          set: _sets[i],
                          onStudy: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => StudyScreen(cards: _sets[i].cards, savedSet: _sets[i]),
                            ));
                            _load(); // reload to reflect updated timesWrong
                          },
                          onDelete: () => _delete(_sets[i]),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}

class _SetTile extends StatelessWidget {
  final FlashcardSet set;
  final VoidCallback onStudy, onDelete;
  const _SetTile({required this.set, required this.onStudy, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final wrongCards = set.cards.where((c) => c.timesWrong > 0).length;
    final dateStr = '${set.createdAt.day}.${set.createdAt.month}.${set.createdAt.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(set.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                overflow: TextOverflow.ellipsis),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Padding(padding: EdgeInsets.only(left: 8),
                child: Text('🗑️', style: TextStyle(fontSize: 18))),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _Chip('${set.cards.length} cards', AppColors.accent),
          const SizedBox(width: 8),
          _Chip(dateStr, AppColors.muted),
          if (wrongCards > 0) ...[
            const SizedBox(width: 8),
            _Chip('$wrongCards to review', AppColors.danger),
          ],
        ]),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: onStudy,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: AppColors.gradient,
            ),
            child: const Center(
              child: Text('🚀  Study', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('📚', style: TextStyle(fontSize: 56)),
        SizedBox(height: 16),
        Text('No saved sets yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        SizedBox(height: 8),
        Text('Generate flashcards and save them\nto study later!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.6)),
      ]),
    );
  }
}
