import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const UplinApp());

class UplinApp extends StatelessWidget {
  const UplinApp({super.key});

  static const Color tealBg = Color(0xFF0097A7);
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uplin – Study Pack',
      theme: ThemeData(
        scaffoldBackgroundColor: tealBg, // App background
        textTheme: GoogleFonts.poppinsTextTheme().apply(
          bodyColor: white, // default text = white
          displayColor: white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: tealBg, // match background
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        // Solid buttons: black background, white text
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
              if (states.contains(MaterialState.disabled)) return Colors.black54;
              return black;
            }),
            foregroundColor: MaterialStateProperty.all<Color>(white),
            overlayColor: MaterialStateProperty.all<Color>(Colors.white12),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            padding: MaterialStateProperty.all(
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
        // Outlined buttons: white background, black text, black border
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            side: MaterialStateProperty.resolveWith<BorderSide>((states) {
              final color = states.contains(MaterialState.disabled) ? Colors.black26 : black;
              return BorderSide(color: color, width: 1.5);
            }),
            backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
              if (states.contains(MaterialState.disabled)) return Colors.white70;
              return white;
            }),
            foregroundColor: MaterialStateProperty.all<Color>(black),
            overlayColor: MaterialStateProperty.all<Color>(Colors.black12),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            padding: MaterialStateProperty.all(
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: black,
          contentTextStyle: TextStyle(color: white),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const UploadPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});
  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  bool _loading = false;
  Uint8List? _zipBytes;
  String _status = 'Pick files and generate a study pack.';
  final String api = 'http://10.0.2.2:8000/generate-study-pack';

  // Keep text strictly white/black; default is white on teal.
  Color get _statusColor {
    return Colors.black;
  }

  Future<void> _pickUploadGenerate() async {
    setState(() {
      _loading = true;
      _status = 'Picking files…';
      _zipBytes = null;
    });

    final picked = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (picked == null || picked.files.isEmpty) {
      setState(() {
        _loading = false;
        _status = 'No files selected.';
      });
      return;
    }

    setState(() => _status = 'Uploading & generating…');

    final req = http.MultipartRequest('POST', Uri.parse(api));
    for (final f in picked.files) {
      final bytes = f.bytes;
      if (bytes != null) {
        req.files.add(http.MultipartFile.fromBytes('files', bytes, filename: f.name));
      } else if (f.path != null) {
        req.files.add(await http.MultipartFile.fromPath('files', f.path!, filename: f.name));
      }
    }

    try {
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        setState(() {
          _zipBytes = res.bodyBytes;
          _status = 'Ready — tap Download or Share.';
        });
      } else {
        setState(() {
          _status = 'Error ${res.statusCode}: ${res.reasonPhrase ?? 'Request failed'}\n${res.body}';
        });
      }
    } catch (e) {
      setState(() => _status = 'Network error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveZip() async {
    if (_zipBytes == null) return;
    await FileSaver.instance.saveFile(
      name: 'study_pack',
      bytes: _zipBytes!,
      ext: 'zip',
      mimeType: MimeType.other,
    );
    setState(() => _status = 'Saved to device as study_pack.zip');
  }

  Future<void> _shareZip() async {
    if (_zipBytes == null) return;
    try {
      await Share.shareXFiles(
        [XFile.fromData(_zipBytes!, name: 'study_pack.zip', mimeType: 'application/zip')],
        subject: 'Uplin study pack',
        text: 'ZIP contains flashcards.csv, outline.md, and study.apkg',
      );
      return;
    } catch (_) {}
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/study_pack.zip');
      await file.writeAsBytes(_zipBytes!, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/zip', name: 'study_pack.zip')],
        subject: 'Uplin study pack',
        text: 'ZIP contains flashcards.csv, outline.md, and study.apkg',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _zipBytes != null;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84, // taller bar
        centerTitle: true,
        title: Align(
          alignment: Alignment.bottomCenter, // pull the title down
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Stack(
              children: [
                // Black outline (stroke)
                Text(
                  'Uplin',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3
                      ..color = Colors.black,
                  ),
                ),
                // White fill
                const Text(
                  'Uplin',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tagline (white text on teal background)
                  Text(
                    "The future of learning — fast, efficient, AI-powered.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Upload card: white background, black text
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Status text black for readability on white card
                        DefaultTextStyle(
                          style: const TextStyle(color: Colors.black),
                          child: Text(
                            _status,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _statusColor,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loading ? null : _pickUploadGenerate,
                          child: Text(_loading ? 'Working…' : 'Choose files & Generate'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: ready ? _saveZip : null,
                                child: const Text('Download ZIP'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: ready ? _shareZip : null,
                                child: const Text('Share ZIP'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
