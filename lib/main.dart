import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('study_data');
  runApp(const NeuroForgeApp());
}

class NeuroForgeApp extends StatelessWidget {
  const NeuroForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroForge Uploader',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: useTestViewer
          ? Scaffold(
              appBar: AppBar(title: const Text('Flashcard Viewer')),
              body: FlashcardViewer(flashcards: dummyCards),
            )
          : const UploadPage(),
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
  final String apiUrl = 'http://10.0.2.2:8000/preview-study-pack';

  Future<void> _pickAndUploadFile() async {
    setState(() {
      _isLoading = true;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final fileBytes = result.files.first.bytes;
      final fileName = result.files.first.name;

      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse(apiUrl),
        );
        request.files.add(http.MultipartFile.fromBytes('files', fileBytes!, filename: fileName));

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);

          final rawCards = List<Map<String, dynamic>>.from(json['flashcards']);
          final flashcardObjects = rawCards.map((card) {
            return Flashcard(
              question: card['front'],
              answer: card['back'],
            );
          }).toList();

          final outline = json['outline'] as String? ?? '';

          final box = Hive.box('study_data');
          await box.put(fileName, {
            'flashcards': rawCards,
            'outline': outline,
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
          _showError('Failed: ${response.statusCode}');
        }
      } catch (e) {
        _showError('Upload error: $e');
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _viewSavedUploads() {
    final box = Hive.box('study_data');
    final keys = box.keys.toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Saved Uploads')),
          body: ListView.builder(
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final fileName = keys[index];
              return ListTile(
                title: Text(fileName),
                onTap: () {
                  final data = box.get(fileName);
                  final flashcardObjects = (data['flashcards'] as List)
                      .map((c) => Flashcard(question: c['front'], answer: c['back']))
                      .toList();
                  final outline = data['outline'] ?? '';
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

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(title: const Text('Error'), content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload to NeuroForge')),
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
