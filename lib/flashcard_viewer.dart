import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  late List<Flashcard> _deck;
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _shuffle = false;

  @override
  void initState() {
    super.initState();
    _deck = List<Flashcard>.from(widget.flashcards);
  }

  void _applyShuffle(bool value) {
    setState(() {
      _shuffle = value;
      _deck = List<Flashcard>.from(widget.flashcards);
      if (_shuffle) _deck.shuffle();
      _currentIndex = 0;
      _showAnswer = false;
    });
  }

  void _nextCard() {
    if (_deck.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _deck.length;
      _showAnswer = false;
    });
  }

  void _restartDeck() {
    setState(() {
      _currentIndex = 0;
      _showAnswer = false;
    });
  }

  void _handleFeedback(String rating) {
    // TODO: integrate SRS persistence (Hive) per card
    debugPrint('User chose: $rating (idx=$_currentIndex)');
    _nextCard();
  }

  Future<void> _exportCsv() async {
    // Build CSV
    final buffer = StringBuffer()..writeln('front,back');
    for (final c in _deck) {
      final front = _csvEscape(c.question);
      final back = _csvEscape(c.answer);
      buffer.writeln('$front,$back');
    }

    // Write to temp
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/neuroforge_flashcards.csv';
    final file = File(path);
    await file.writeAsString(buffer.toString());

    // Share
    await Share.shareXFiles(
      [XFile(path)],
      text: 'NeuroForge flashcards (CSV)',
      subject: 'NeuroForge Flashcards',
    );
  }

  String _csvEscape(String s) {
    final needsQuotes = s.contains(',') || s.contains('"') || s.contains('\n');
    final escaped = s.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  void _viewOutline() {
    final text = widget.outlineText ?? '';
    if (text.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutlineScreen(markdownText: text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_deck.isEmpty) {
      return const Center(child: Text('No flashcards to display.'));
    }

    final flashcard = _deck[_currentIndex];
    final cardCount = _deck.length;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Card ${_currentIndex + 1} of $cardCount',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 16),
                FilterChip(
                  label: const Text('Shuffle'),
                  selected: _shuffle,
                  onSelected: _applyShuffle,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.download),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: Card(
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
            const SizedBox(height: 16),
            if ((widget.outlineText ?? '').isNotEmpty)
              ElevatedButton.icon(
                onPressed: _viewOutline,
                icon: const Icon(Icons.menu_book),
                label: const Text('View Outline'),
              ),
            const SizedBox(height: 16),
            if (_currentIndex == cardCount - 1)
              ElevatedButton.icon(
                onPressed: _restartDeck,
                icon: const Icon(Icons.refresh),
                label: const Text('Restart Deck'),
              ),
          ],
        ),
      ),
    );
  }
}

class OutlineScreen extends StatefulWidget {
  final String markdownText;
  const OutlineScreen({super.key, required this.markdownText});

  @override
  State<OutlineScreen> createState() => _OutlineScreenState();
}

class _OutlineScreenState extends State<OutlineScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.trim().isEmpty
        ? widget.markdownText
        : _filterMarkdown(widget.markdownText, _query);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outline'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search in outline…',
                filled: true,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: Markdown(
        data: filtered,
        padding: const EdgeInsets.all(16),
        styleSheet: MarkdownStyleSheet(
          h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          p: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  String _filterMarkdown(String md, String q) {
    final query = q.toLowerCase();
    final lines = md.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      if (line.toLowerCase().contains(query)) kept.add(line);
    }
    // Show original if nothing matches to avoid a blank screen
    return kept.isEmpty ? md : kept.join('\n');
  }
}
