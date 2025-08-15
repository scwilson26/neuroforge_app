import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const NeuroForgeApp());

class NeuroForgeApp extends StatelessWidget {
  const NeuroForgeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroForge – Study Pack',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        textTheme: GoogleFonts.poppinsTextTheme().apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        // Visible elevated buttons even when disabled
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.disabled)) return const Color(0xFF1E2A3A);
              return Colors.blueAccent;
            }),
            foregroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.disabled)) return Colors.white70;
              return Colors.white;
            }),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            side: MaterialStateProperty.resolveWith((states) {
              final c = states.contains(MaterialState.disabled) ? Colors.white24 : Colors.blueAccent;
              return BorderSide(color: c, width: 1.5);
            }),
            foregroundColor: MaterialStateProperty.resolveWith((states) {
              return states.contains(MaterialState.disabled) ? Colors.white70 : Colors.blueAccent;
            }),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 14)),
          ),
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

  Color get _statusColor {
    if (_status.startsWith('Error')) return Colors.redAccent;
    if (_status.startsWith('Ready')) return Colors.lightBlueAccent;
    if (_status.startsWith('Saved')) return Colors.lightBlueAccent;
    return Colors.white70;
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
        subject: 'NeuroForge study pack',
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
        subject: 'NeuroForge study pack',
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
      appBar: AppBar(title: const Text('NeuroForge – Generate Study Pack')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1115),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _statusColor),
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
            ),
          ),
        ),
      ),
    );
  }
}
