import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'flashcard.dart';

class FlashcardViewer extends StatefulWidget {
  final List<Flashcard> flashcards;
  final String? outlineText;

  const FlashcardViewer({
    super.key,
    required this.flashcards,
    this.outlineText,
  });

  @override
  State<FlashcardViewer> createState() => _FlashcardViewerState();
}

class _FlashcardViewerState extends State<FlashcardViewer> {
  int _currentIndex = 0;
  bool _showAnswer = false;

  void _nextCard() {
    if (widget.flashcards.isEmpty) return;

    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.flashcards.length;
      _showAnswer = false;
    });
  }

  void _handleFeedback(String rating) {
    print('User chose: $rating'); // Future: hook into SRS logic here
    _nextCard();
  }

  void _restartDeck() {
    setState(() {
      _currentIndex = 0;
      _showAnswer = false;
    });
  }

  void _viewOutline() {
    if (widget.outlineText == null || widget.outlineText!.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Outline')),
          body: Markdown(
            data: widget.outlineText!,
            padding: const EdgeInsets.all(16),
            styleSheet: MarkdownStyleSheet(
              h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              p: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flashcards = widget.flashcards;

    if (flashcards.isEmpty) {
      return const Center(child: Text('No flashcards to display.'));
    }

    final flashcard = flashcards[_currentIndex];
    final cardCount = flashcards.length;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Text(
              'Card ${_currentIndex + 1} of $cardCount',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showAnswer = !_showAnswer;
                });
              },
              child: Card(
                color: Colors.white,
                elevation: 8,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  height: 250,
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _showAnswer ? flashcard.answer : flashcard.question,
                      key: ValueKey(_showAnswer),
                      style: const TextStyle(fontSize: 20, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _handleFeedback('Again'),
                  child: const Text('Again'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () => _handleFeedback('Good'),
                  child: const Text('Good'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () => _handleFeedback('Easy'),
                  child: const Text('Easy'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (widget.outlineText != null && widget.outlineText!.isNotEmpty)
              ElevatedButton(
                onPressed: _viewOutline,
                child: const Text('📖 View Outline'),
              ),
            const SizedBox(height: 16),
            if (_currentIndex == cardCount - 1)
              ElevatedButton(
                onPressed: _restartDeck,
                child: const Text('🔁 Restart Deck'),
              ),
          ],
        ),
      ),
    );
  }
}
