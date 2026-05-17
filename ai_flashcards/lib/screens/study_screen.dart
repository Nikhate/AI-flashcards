import 'dart:math';
import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import '../models/flashcard_set.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';

class StudyScreen extends StatefulWidget {
  final List<Flashcard> cards;
  final FlashcardSet? savedSet;

  const StudyScreen({super.key, required this.cards, this.savedSet});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  late List<Flashcard> _deck;
  int _index = 0;
  bool _showAnswer = false;
  int _knownCount = 0;
  bool _done = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _deck = _buildDeck(widget.cards);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  List<Flashcard> _buildDeck(List<Flashcard> cards) {
    final deck = <Flashcard>[];
    for (final card in cards) {
      final times = 1 + card.timesWrong;
      for (int i = 0; i < times.clamp(1, 3); i++) {
        deck.add(card);
      }
    }
    deck.shuffle(Random());
    return deck;
  }

  void _reveal() => setState(() => _showAnswer = true);

  void _next({required bool knew}) async {
    final card = _deck[_index];
    if (!knew) {
      card.timesWrong = (card.timesWrong + 1).clamp(0, 5);
    } else if (card.timesWrong > 0) {
      card.timesWrong--;
    }
    if (widget.savedSet != null) {
      await StorageService.updateSet(widget.savedSet!);
    }
    _fadeCtrl.reset();
    setState(() {
      _showAnswer = false;
      if (knew) _knownCount++;
      if (_index + 1 >= _deck.length) {
        _done = true;
      } else {
        _index++;
      }
    });
    _fadeCtrl.forward();
  }

  void _restart() {
    _fadeCtrl.reset();
    setState(() {
      _deck = _buildDeck(widget.cards);
      _index = 0;
      _knownCount = 0;
      _done = false;
      _showAnswer = false;
    });
    _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _done
            ? _ResultsView(
                total: _deck.length,
                known: _knownCount,
                wrongCards: widget.cards.where((c) => c.timesWrong > 0).length,
                onRestart: _restart,
                onBack: () => Navigator.pop(context),
              )
            : _StudyView(
                card: _deck[_index],
                index: _index,
                total: _deck.length,
                showAnswer: _showAnswer,
                fadeAnim: _fadeAnim,
                onReveal: _reveal,
                onKnew: () => _next(knew: true),
                onDidntKnow: () => _next(knew: false),
                onBack: () => Navigator.pop(context),
              ),
      ),
    );
  }
}

// ── Study view ───────────────────────────────────────────────

class _StudyView extends StatelessWidget {
  final Flashcard card;
  final int index;
  final int total;
  final bool showAnswer;
  final Animation<double> fadeAnim;
  final VoidCallback onReveal;
  final VoidCallback onKnew;
  final VoidCallback onDidntKnow;
  final VoidCallback onBack;

  const _StudyView({
    required this.card, required this.index, required this.total,
    required this.showAnswer, required this.fadeAnim,
    required this.onReveal, required this.onKnew,
    required this.onDidntKnow, required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom,
        ),
        child: IntrinsicHeight(
          child: Column(children: [
            _TopBar(index: index, total: total, onBack: onBack),
            const SizedBox(height: 14),
            _ProgressBar(value: index / total),
            const SizedBox(height: 24),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FadeTransition(
                  opacity: fadeAnim,
                  child: _CardFace(card: card, showAnswer: showAnswer, onTap: showAnswer ? null : onReveal),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (showAnswer)
              _ActionRow(onKnew: onKnew, onDidntKnow: onDidntKnow)
            else
              const SizedBox(height: 80),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int index, total;
  final VoidCallback onBack;
  const _TopBar({required this.index, required this.total, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.cardBg, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Text('← Back', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
        const Spacer(),
        Text('${index + 1} / $total',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
      ]),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: value, minHeight: 4,
          backgroundColor: AppColors.cardBorder,
          valueColor: const AlwaysStoppedAnimation(AppColors.accent),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final Flashcard card;
  final bool showAnswer;
  final VoidCallback? onTap;
  const _CardFace({required this.card, required this.showAnswer, this.onTap});

  Widget _dot(Color color, String label) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.muted)),
  ]);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.cardBg, borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _dot(AppColors.accent, 'Question'),
            if (card.timesWrong > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.dangerBorder)),
                child: Text('Review ${card.timesWrong}x', style: const TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Text(card.question, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19, height: 1.5)),
            ),
          ),
          if (showAnswer) ...[
            const Divider(color: AppColors.cardBorder),
            const SizedBox(height: 12),
            _dot(AppColors.accentPink, 'Answer'),
            const SizedBox(height: 8),
            Text(card.answer, style: const TextStyle(fontSize: 15, color: AppColors.muted, height: 1.6)),
          ] else
            Center(
              child: Text('tap to reveal answer',
                  style: TextStyle(fontSize: 12, color: AppColors.cardBorder.withOpacity(0.9))),
            ),
        ]),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final VoidCallback onKnew, onDidntKnow;
  const _ActionRow({required this.onKnew, required this.onDidntKnow});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(child: _ActionButton(
          label: '✕  Not yet', textColor: AppColors.danger,
          bgColor: AppColors.dangerBg, borderColor: AppColors.dangerBorder, onTap: onDidntKnow,
        )),
        const SizedBox(width: 12),
        Expanded(child: _ActionButton(
          label: '✓  Got it!', textColor: AppColors.success,
          bgColor: AppColors.successBg, borderColor: AppColors.successBorder, onTap: onKnew,
        )),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color textColor, bgColor, borderColor;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.textColor, required this.bgColor, required this.borderColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor, width: 1.5)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor))),
      ),
    );
  }
}

// ── Results view ─────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  final int total, known, wrongCards;
  final VoidCallback onRestart, onBack;
  const _ResultsView({required this.total, required this.known, required this.wrongCards, required this.onRestart, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final missed = total - known;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🎉', style: TextStyle(fontSize: 60)),
        const SizedBox(height: 20),
        const Text('Session complete!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('You went through $total cards.\nCards to review next time: $wrongCards',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.6)),
        const SizedBox(height: 32),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _StatBox(value: '$known', label: 'Got it', color: AppColors.accent),
          const SizedBox(width: 16),
          _StatBox(value: '$missed', label: 'Not yet', color: AppColors.accentPink),
        ]),
        const SizedBox(height: 12),
        if (wrongCards > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.dangerBorder),
              ),
              child: Text(
                '🔄 $wrongCards card${wrongCards == 1 ? '' : 's'} will appear more often next session',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.danger),
              ),
            ),
          ),
        const SizedBox(height: 8),
        GradientButton(label: '🔀  Study Again (shuffled)', onTap: onRestart),
        const SizedBox(height: 12),
        OutlineButton(label: '← Back', color: AppColors.muted, onTap: onBack),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatBox({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ]),
    );
  }
}