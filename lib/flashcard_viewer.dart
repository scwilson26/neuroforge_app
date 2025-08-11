import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';

import 'flashcard.dart';

class FlashcardViewer extends StatefulWidget {
  final List<Flashcard> flashcards;
  final String? outlineText;

  /// If provided, we’ll use these files to build the full ZIP
  /// without asking the user to re-pick.
  final List<PlatformFile>? originalFiles;

  const FlashcardViewer({
    super.key,
    required this.flashcards,
    this.outlineText,
    this.originalFiles,
  });

  @override
  State<FlashcardViewer> createState() => _FlashcardViewerState();
}

class _FlashcardViewerState extends State<FlashcardViewer> {
  int index = 0;
  bool showAnswer = false;
  bool _busy = false;

  String get _baseUrl =>
      kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  String get _zipUrl => '$_baseUrl/generate-study-pack';

  void _next([bool resetAnswer = true]) {
    setState(() {
      index = (index + 1) % widget.flashcards.length;
      if (resetAnswer) showAnswer = false;
    });
  }

  void _shuffle() {
    setState(() {
      widget.flashcards.shuffle();
      index = 0;
      showAnswer = false;
    });
  }

  Future<void> _shareOrDownloadFullPack() async {
    // If we don’t have the original upload files, we can’t hit /generate-study-pack
    // without asking the user to re-pick. In that case, nudge them.
    if (widget.originalFiles == null || widget.originalFiles!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Re-upload files from the main screen to share the full pack.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final req = http.MultipartRequest('POST', Uri.parse(_zipUrl));
      for (final f in widget.originalFiles!) {
        if (f.bytes != null) {
          req.files.add(http.MultipartFile.fromBytes('files', f.bytes!, filename: f.name));
        } else if (f.path != null) {
          req.files.add(await http.MultipartFile.fromPath('files', f.path!, filename: f.name));
        }
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final bytes = resp.bodyBytes;

        if (kIsWeb) {
          await FileSaver.instance.saveFile(
            name: 'neuroforge_study_pack',
            bytes: bytes,
            ext: 'zip',
            mimeType: MimeType.other,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ZIP downloaded.')),
          );
        } else {
          await Share.shareXFiles(
            [XFile.fromData(bytes, name: 'study_pack.zip', mimeType: 'application/zip')],
            text: 'NeuroForge study pack (.csv + .md + .apkg)',
            subject: 'NeuroForge study pack',
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${resp.statusCode}\n${resp.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.flashcards[index];

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row
              Row(
                children: [
                  Text('Card ${index + 1} of ${widget.flashcards.length}',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _busy ? null : _shuffle,
                    child: const Text('Shuffle'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _shareOrDownloadFullPack,
                    icon: const Icon(Icons.ios_share),
                    label: Text(kIsWeb
                        ? 'Download Full Study Pack'
                        : 'Share/Download Full Study Pack'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Card
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => showAnswer = !showAnswer),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          showAnswer ? card.answer : card.question,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Simple review buttons (placeholder)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _pill('Again', Colors.red.shade400, () => _next()),
                  _pill('Good', Colors.orange.shade400, () => _next()),
                  _pill('Easy', Colors.green.shade400, () => _next()),
                ],
              ),

              const SizedBox(height: 12),

              if ((widget.outlineText ?? '').isNotEmpty)
                Center(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('View Outline'),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => DraggableScrollableSheet(
                          expand: false,
                          builder: (ctx, sc) => SingleChildScrollView(
                            controller: sc,
                            padding: const EdgeInsets.all(16),
                            child: Text(widget.outlineText!),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),

        if (_busy)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _pill(String text, Color color, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: const StadiumBorder(),
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      ),
      onPressed: onTap,
      child: Text(text),
    );
  }
}
