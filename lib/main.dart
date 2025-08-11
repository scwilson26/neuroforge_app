import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
    answer: 'Just tap the card to toggle between question and answer.',
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

/// Resolve API URL for web vs Android emulator.
/// - Web: use 127.0.0.1 (browser hits your machine directly)
/// - Android emulator: host machine is 10.0.2.2
String get _apiUrl {
  final base = kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  return '$base/preview-study-pack';
}

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

  Future<void> _pickAndUploadFile() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt', 'png', 'jpg', 'jpeg'],
        withData: true, // web needs this
      );

      if (result == null || result.files.isEmpty) {
        return; // user canceled
      }

      final picked = result.files.first;
      final fileName = picked.name;

      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));

      if (picked.bytes != null) {
        // Web (and sometimes desktop) gives bytes
        request.files.add(
          http.MultipartFile.fromBytes('files', picked.bytes!, filename: fileName),
        );
      } else if (picked.path != null) {
        // Mobile/desktop path upload without needing dart:io import
        request.files.add(
          await http.MultipartFile.fromPath('files', picked.path!, filename: fileName),
        );
      } else {
        _showError('Could not read the selected file.');
        return;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.body);

        // Parse flashcards
        final rawCards = List<Map<String, dynamic>>.from(jsonBody['flashcards']);
        final flashcardObjects = rawCards
            .map((c) => Flashcard(question: c['front'], answer: c['back']))
            .toList();

        // Parse outline
        final outline = jsonBody['outline'] as String? ?? '';

        // Save the full set under file name
        final box = Hive.box('study_data');
        await box.put(fileName, {
          'flashcards': rawCards,
          'outline': outline,
          'savedAt': DateTime.now().toIso8601String(),
        });

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(fileName)),
              body: FlashcardViewer(
                flashcards: flashcardObjects,
                outlineText: outline,
              ),
            ),
          ),
        );
      } else {
        _showError('Failed: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      _showError('Upload error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _viewSavedUploads() {
    final box = Hive.box('study_data');
    final keys = box.keys
        .where((k) => k != 'dark_mode') // filter out settings key
        .toList();

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
                          _viewSavedUploads(); // refresh list
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
              onPressed: _isLoading ? null : _pickAndUploadFile,
              child: const Text('Select and Upload File'),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const LinearProgressIndicator(),
            const Spacer(),
            ElevatedButton(
              onPressed: _viewSavedUploads,
              child: const Text('📚 Review Previous Uploads'),
            ),
          ],
        ),
      ),
    );
  }
}
