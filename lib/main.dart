import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';

import 'flashcard.dart';
import 'flashcard_viewer.dart';

const bool useTestViewer = false;

final dummyCards = [
  Flashcard(
    question: 'What is Flutter?',
    answer: 'A UI toolkit made by Google to build apps with one codebase.',
  ),
  Flashcard(
    question: 'What is Dart?',
    answer: 'The programming language used by Flutter.',
  ),
  Flashcard(
    question: 'How do you flip a flashcard?',
    answer: 'Tap the card to toggle Q/A.',
  ),
];

Future<void> _ensureHive() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('study_data');
  final box = Hive.box('study_data');
  if (!box.containsKey('dark_mode')) {
    await box.put('dark_mode', false);
  }
}

/// Android emulator uses 10.0.2.2 to reach host; web uses 127.0.0.1.
String get _baseUrl =>
    kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';

String get _previewUrl => '$_baseUrl/preview-study-pack';
String get _zipUrl => '$_baseUrl/generate-study-pack';

void main() async {
  await _ensureHive();
  runApp(const NeuroForgeApp());
}

class NeuroForgeApp extends StatelessWidget {
  const NeuroForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('study_data');
    return ValueListenableBuilder(
      valueListenable: box.listenable(keys: ['dark_mode']),
      builder: (_, __, ___) {
        final isDark = box.get('dark_mode', defaultValue: false) as bool;
        return MaterialApp(
          title: 'NeuroForge',
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            primarySwatch: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          home: useTestViewer
              ? Scaffold(
                  appBar: AppBar(title: const Text('Flashcard Viewer')),
                  body: FlashcardViewer(flashcards: dummyCards),
                )
              : const UploadPage(),
        );
      },
    );
  }
}

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});
  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  bool _isLoading = false;

  // Store last-picked files + preview to enable post-upload options
  List<PlatformFile>? _lastPickedFiles;
  List<Flashcard> _lastFlashcards = [];
  String _lastOutline = '';
  String? _lastLabel; // for Saved Uploads entry

  Future<List<PlatformFile>?> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'png', 'jpg', 'jpeg'],
      withData: true,
      allowMultiple: true, // matches your backend
    );
    if (result == null || result.files.isNotEmpty == false) return null;
    return result.files;
  }

  Future<void> _uploadForPreview() async {
    setState(() => _isLoading = true);
    try {
      final files = await _pickFiles();
      if (files == null) return;

      final req = http.MultipartRequest('POST', Uri.parse(_previewUrl));
      for (final f in files) {
        if (f.bytes != null) {
          req.files.add(http.MultipartFile.fromBytes('files', f.bytes!, filename: f.name));
        } else if (f.path != null) {
          req.files.add(await http.MultipartFile.fromPath('files', f.path!, filename: f.name));
        } else {
          _showError('Could not read one of the selected files.');
          return;
        }
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final rawCards = List<Map<String, dynamic>>.from(body['flashcards']);
        final outline = body['outline'] as String? ?? '';

        final cards = rawCards
            .map((c) => Flashcard(question: c['front'], answer: c['back']))
            .toList();

        // Save preview to Hive
        final box = Hive.box('study_data');
        final label =
            'Upload ${DateTime.now().toIso8601String().replaceAll("T", " ").split(".").first}';
        await box.put(label, {
          'flashcards': rawCards,
          'outline': outline,
          'savedAt': DateTime.now().toIso8601String(),
        });

        setState(() {
          _lastPickedFiles = files;
          _lastFlashcards = cards;
          _lastOutline = outline;
          _lastLabel = label;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload complete. Choose an option below.')),
        );
      } else {
        _showError('Preview failed: ${resp.statusCode}\n${resp.body}');
      }
    } catch (e) {
      _showError('Upload error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _useFlashcardsNow() async {
    if (_lastFlashcards.isEmpty) {
      _showError('Upload a file first.');
      return;
    }
    final title = _lastLabel ?? 'Flashcards';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: FlashcardViewer(
            flashcards: _lastFlashcards,
            outlineText: _lastOutline,
            originalFiles: _lastPickedFiles, // ✅ pass original files to viewer
          ),
        ),
      ),
    );
  }

  Future<void> _downloadOrShareZip() async {
    if (_lastPickedFiles == null || _lastPickedFiles!.isEmpty) {
      _showError('Upload a file first.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final req = http.MultipartRequest('POST', Uri.parse(_zipUrl));
      for (final f in _lastPickedFiles!) {
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
          // Web: save ZIP directly
          await FileSaver.instance.saveFile(
            name: 'neuroforge_study_pack',
            bytes: bytes,
            ext: 'zip',
            mimeType: MimeType.other,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ZIP saved.')),
          );
        } else {
          // Android/iOS/Desktop: open native share sheet (Gmail/Drive/Files…)
          await Share.shareXFiles(
            [
              XFile.fromData(
                bytes,
                name: 'study_pack.zip',
                mimeType: 'application/zip',
              ),
            ],
            text: 'NeuroForge study pack (.csv + .md + .apkg)',
            subject: 'NeuroForge study pack',
          );
        }
      } else {
        _showError('Download failed: ${resp.statusCode}\n${resp.body}');
      }
    } catch (e) {
      _showError('Download error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _viewSavedUploads() {
    final box = Hive.box('study_data');
    final keys = box.keys.where((k) => k != 'dark_mode').toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Saved Uploads')),
          body: keys.isEmpty
              ? const Center(child: Text('No saved uploads yet.'))
              : ListView.builder(
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    final fileName = keys[index] as String;
                    final data = box.get(fileName) as Map?;
                    final savedAt = data?['savedAt'] as String? ?? '';

                    return ListTile(
                      title: Text(fileName),
                      subtitle: savedAt.isNotEmpty ? Text('Saved: $savedAt') : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await box.delete(fileName);
                          if (!mounted) return;
                          Navigator.pop(context);
                          _viewSavedUploads(); // refresh
                        },
                      ),
                      onTap: () {
                        final flashcardObjects =
                            (data?['flashcards'] as List<dynamic>? ?? [])
                                .map((c) => Flashcard(
                                      question: c['front'],
                                      answer: c['back'],
                                    ))
                                .toList();
                        final outline = (data?['outline'] as String?) ?? '';
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: Text(fileName)),
                              body: FlashcardViewer(
                                flashcards: flashcardObjects,
                                outlineText: outline,
                                // no originalFiles here (loaded from storage)
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _toggleTheme() {
    final box = Hive.box('study_data');
    final current = box.get('dark_mode', defaultValue: false) as bool;
    box.put('dark_mode', !current);
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Hive.box('study_data').get('dark_mode', defaultValue: false) as bool;

    final bool hasPostUploadOptions =
        _lastPickedFiles != null && _lastFlashcards.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload to NeuroForge'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _uploadForPreview,
              child: const Text('📤 Upload file'),
            ),
            const SizedBox(height: 16),

            if (hasPostUploadOptions) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _useFlashcardsNow,
                      child: const Text('📚 Use flashcards now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _downloadOrShareZip,
                      child: Text(kIsWeb
                          ? '⬇️ Download full study pack'
                          : '📤 Share/Download full study pack'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Full pack includes CSV + outline.md + Anki .apkg',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
            ],

            if (_isLoading) const LinearProgressIndicator(),
            const Spacer(),
            ElevatedButton(
              onPressed: _viewSavedUploads,
              child: const Text('📦 Review Previous Uploads'),
            ),
          ],
        ),
      ),
    );
  }
}
