import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import '../theme/app_theme.dart';

class FlashcardTile extends StatefulWidget {
  final Flashcard card;
  final int index;

  const FlashcardTile({super.key, required this.card, required this.index});

  @override
  State<FlashcardTile> createState() => _FlashcardTileState();
}

class _FlashcardTileState extends State<FlashcardTile>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _controller;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _controller.forward() : _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _open ? AppColors.accent : AppColors.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label(dot: AppColors.accent, text: 'Q${widget.index + 1}'),
            const SizedBox(height: 10),
            Text(
              widget.card.question,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.5,
                color: Colors.white,
              ),
            ),
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.cardBorder, height: 1),
                  const SizedBox(height: 14),
                  _Label(dot: AppColors.accentPink, text: 'Answer'),
                  const SizedBox(height: 6),
                  Text(
                    widget.card.answer,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            if (!_open) ...[
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'tap to reveal ↓',
                  style: TextStyle(fontSize: 11, color: AppColors.cardBorder),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final Color dot;
  final String text;
  const _Label({required this.dot, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}
