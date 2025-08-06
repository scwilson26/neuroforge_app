import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class OutlineViewer extends StatelessWidget {
  final String markdownText;

  const OutlineViewer({super.key, required this.markdownText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outline')),
      body: Markdown(
        data: markdownText,
        padding: const EdgeInsets.all(16),
        styleSheet: MarkdownStyleSheet(
          h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          p: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
