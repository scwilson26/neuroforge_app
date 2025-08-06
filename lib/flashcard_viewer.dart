import 'package:flutter/material.dart';
import 'flashcard.dart';

class FlashcardViewer extends StatefulWidget {
  final List<Flashcard> flashcards;

  const FlashcardViewer({super.key, required this.flashcards});

  @override
  State<FlashcardViewer> createState() => _FlashcardViewerState();
}

class _FlashcardViewerState extends State<FlashcardViewer> {
  int _currentIndex = 0;
  bool _showAnswer = false;

  void _nextCard() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.flashcards.length;
      _showAnswer = false;
    });
  }

  void _previousCard() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + widget.flashcards.length) % widget.flashcards.length;
      _showAnswer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final flashcard = widget.flashcards[_currentIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _showAnswer = !_showAnswer;
            });
          },
          child: Card(
            elevation: 6,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(24),
              height: 250,
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  _showAnswer ? flashcard.answer : flashcard.question,
                  key: ValueKey(_showAnswer),
                  style: const TextStyle(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(onPressed: _previousCard, child: const Text('Previous')),
            ElevatedButton(onPressed: _nextCard, child: const Text('Next')),
          ],
        ),
      ],
    );
  }
}
