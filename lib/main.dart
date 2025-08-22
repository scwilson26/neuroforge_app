import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

void main() => runApp(const SpacedApp());

class SpacedApp extends StatelessWidget {
  const SpacedApp({super.key});

  static const Color seed = Color(0xFF0097A7);

  @override
  Widget build(BuildContext context) {
    final baseText = GoogleFonts.poppinsTextTheme();
    TextTheme textTheme = baseText.copyWith(
      // Title (screen title)
      headlineSmall: baseText.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      // Body
      bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
      // Caption
      bodySmall: baseText.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w400),
    );
    final lightScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    final darkScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

    return MaterialApp(
      title: 'Spaced – Study Pack',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        scaffoldBackgroundColor: lightScheme.background,
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.surface,
          foregroundColor: lightScheme.onSurface,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(88, 52)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: lightScheme.inverseSurface,
          contentTextStyle: TextStyle(color: lightScheme.onInverseSurface),
          behavior: SnackBarBehavior.floating,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          isDense: false,
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        dividerTheme: DividerThemeData(color: lightScheme.outlineVariant, space: 1, thickness: 1),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: darkScheme.background,
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surface,
          foregroundColor: darkScheme.onSurface,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(88, 52)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: darkScheme.inverseSurface,
          contentTextStyle: TextStyle(color: darkScheme.onInverseSurface),
          behavior: SnackBarBehavior.floating,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          isDense: false,
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        dividerTheme: DividerThemeData(color: darkScheme.outlineVariant, space: 1, thickness: 1),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = false;
  String _status = '';
  final String previewApi = 'http://10.0.2.2:8000/preview-study-pack?limit=200';
  List<PlatformFile> _selectedFiles = [];
  http.Client? _client;
  bool _cancelled = false;
  int _progressStage = 0;
  static const List<String> _stages = [
    'Extracting…',
    'Finding high-yield…',
    'Building cards…',
    'Packing your study pack…',
  ];

  void _startProgressTicker() {
    _progressStage = 0;
    Future.doWhile(() async {
      if (!_loading) return false;
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_loading) return false;
      if (mounted) setState(() => _progressStage = (_progressStage + 1) % _stages.length);
      return _loading;
    });
  }

  Future<void> _pickAndPreview() async {
    setState(() {
      _loading = true;
      _status = '';
      _selectedFiles = [];
      _cancelled = false;
    });
    _startProgressTicker();

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
    );
    if (picked == null || picked.files.isEmpty) {
      setState(() {
        _loading = false;
        _status = 'No files selected.';
      });
      return;
    }
    _selectedFiles = picked.files;

    final req = http.MultipartRequest('POST', Uri.parse(previewApi));
    for (final f in picked.files) {
      if (f.bytes != null) {
        req.files.add(http.MultipartFile.fromBytes('files', f.bytes!, filename: f.name));
      } else if (f.path != null) {
        req.files.add(await http.MultipartFile.fromPath('files', f.path!, filename: f.name));
      }
    }

    try {
      _client = http.Client();
      final streamed = await _client!.send(req);
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final cards = (body['flashcards'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final outline = (body['outline'] ?? '').toString();
        // Save session locally
        final session = StudySession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          createdAt: DateTime.now(),
          flashcards: cards,
          outline: outline,
        );
        await StudyStorage.saveSession(session);
        if (!mounted) return;
        if (_cancelled) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PreviewScreen(
              originalFiles: _selectedFiles,
              flashcards: cards,
              outline: outline,
            ),
          ),
        );
      } else {
        setState(() {
          _status = 'Error ${res.statusCode}: ${res.reasonPhrase ?? 'Request failed'}';
        });
      }
    } catch (e) {
      if (!_cancelled) {
        setState(() {
          _status = 'Network error: $e';
        });
      }
    } finally {
      _client?.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Turn notes into a study system.',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'PDF, DOCX, TXT, Images.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(color: textTheme.bodyMedium?.color?.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1 Upload • 2 Preview • 3 Study',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(color: textTheme.bodySmall?.color?.withOpacity(0.7)),
                      ),
            const SizedBox(height: 24),
                      Semantics(
                        button: true,
                        label: 'Upload notes',
                        child: ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          onPressed: _loading ? null : _pickAndPreview,
                          child: const Text('Upload notes'),
                        ),
                      ),
            const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(88, 52)),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LibraryScreen()),
                          ),
                          child: const Text('Previous packs'),
                        ),
                      ),
                      if (_status.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(_status, textAlign: TextAlign.center),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_loading)
              Positioned.fill(
                child: Stack(
                  children: [
                    // Modal barrier
                    ModalBarrier(color: theme.colorScheme.scrim.withOpacity(0.6), dismissible: false),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Card(
                          elevation: 0,
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 3),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(_stages[_progressStage], style: textTheme.bodyMedium),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        style: TextButton.styleFrom(minimumSize: const Size(88, 52)),
                                        onPressed: () {
                                          _cancelled = true;
                                          _client?.close();
                                          if (mounted) setState(() => _loading = false);
                                        },
                                        child: const Text('Cancel'),
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
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PreviewScreen extends StatefulWidget {
  final List<PlatformFile>? originalFiles;
  final List<Map<String, dynamic>> flashcards;
  final String outline;
  const PreviewScreen({super.key, this.originalFiles, required this.flashcards, required this.outline});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

enum PreviewTab { flashcards, outline }

class _PreviewScreenState extends State<PreviewScreen> {
  PreviewTab _tab = PreviewTab.flashcards;
  late List<bool> _selected;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _selected = List<bool>.filled(widget.flashcards.length, true);
  }

  Future<void> _downloadStudyPack() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
  final req = http.MultipartRequest('POST', Uri.parse('http://10.0.2.2:8000/generate-study-pack'));
  final files = widget.originalFiles ?? const <PlatformFile>[];
  for (final f in files) {
        if (f.bytes != null) {
          req.files.add(http.MultipartFile.fromBytes('files', f.bytes!, filename: f.name));
        } else if (f.path != null) {
          req.files.add(await http.MultipartFile.fromPath('files', f.path!, filename: f.name));
        }
      }
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final bytes = res.bodyBytes;
        // Web or if share is unavailable: save the file instead.
        if (kIsWeb) {
          await FileSaver.instance.saveFile(
            name: 'study_pack',
            bytes: bytes,
            ext: 'zip',
            mimeType: MimeType.other,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved study_pack.zip')));
          }
        } else {
          try {
            await Share.shareXFiles([
              XFile.fromData(bytes, name: 'study_pack.zip', mimeType: 'application/zip'),
            ], text: 'Your study pack is ready!');
          } catch (_) {
            await FileSaver.instance.saveFile(
              name: 'study_pack',
              bytes: bytes,
              ext: 'zip',
              mimeType: MimeType.other,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved study_pack.zip')));
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: ${res.statusCode} ${res.reasonPhrase ?? ''}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _goStudy() {
    final kept = <Map<String, dynamic>>[];
    for (var i = 0; i < widget.flashcards.length; i++) {
      if (_selected[i]) kept.add(widget.flashcards[i]);
    }
    if (kept.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one card')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StudyScreen(cards: kept)),
    );
  }

  int get _selectedCount => _selected.where((e) => e).length;

  void _setTab(PreviewTab t) {
    setState(() => _tab = t);
    // Accessibility: Announce tab change
    final label = t == PreviewTab.flashcards ? 'Flashcards' : 'Outline';
    SemanticsService.announce(label, TextDirection.ltr);
  }

  void _bulkSelect(bool value) {
    HapticFeedback.lightImpact();
    setState(() {
      for (var i = 0; i < _selected.length; i++) {
        _selected[i] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
  return Scaffold(
    appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Preview'),
            if (_selectedCount > 0)
              Text('${_selectedCount} selected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75))),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'all') _bulkSelect(true);
              if (v == 'none') _bulkSelect(false);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('Select all')),
              PopupMenuItem(value: 'none', child: Text('Deselect all')),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<PreviewTab>(
              segments: const [
                ButtonSegment(value: PreviewTab.flashcards, label: Text('Flashcards'), icon: Icon(Icons.style_outlined)),
                ButtonSegment(value: PreviewTab.outline, label: Text('Outline'), icon: Icon(Icons.article_outlined)),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => _setTab(s.first),
              style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(primary),
              ),
            ),
          ),
      const SizedBox(height: 8),
          Expanded(
            child: _tab == PreviewTab.flashcards
                ? _buildCardList()
                : _buildOutlineView(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _downloading || (widget.originalFiles == null || widget.originalFiles!.isEmpty)
                      ? null
                      : _downloadStudyPack,
                  child: Text(_downloading ? 'Preparing…' : 'Download study pack'),
                ),
              ),
        const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _selectedCount == 0 ? null : _goStudy,
                  child: const Text('Study now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardList() {
    final cards = widget.flashcards;
    if (cards.isEmpty) {
      return _EmptyState(
        message: 'No flashcards found',
        actionText: 'Retry upload',
        onTap: () => Navigator.of(context).pop(),
      );
    }
  return ListView.separated(
      itemCount: cards.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = cards[i];
        final front = (c['front'] ?? '').toString();
        return StatefulBuilder(
          builder: (context, setLocal) => ListTile(
      title: Text(front, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            trailing: Checkbox(
              value: _selected[i],
              onChanged: (v) {
                final nv = v ?? true;
                setLocal(() {});
                setState(() => _selected[i] = nv);
              },
            ),
            onTap: () {
              final nv = !_selected[i];
              setLocal(() {});
              setState(() => _selected[i] = nv);
            },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            visualDensity: VisualDensity.compact,
          ),
        );
      },
    );
  }

  Widget _buildOutlineView() {
    final text = widget.outline.trim();
    if (text.isEmpty) {
      return _EmptyState(
        message: 'No outline yet',
        actionText: 'Retry upload',
        onTap: () => Navigator.of(context).pop(),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String actionText;
  final VoidCallback onTap;
  const _EmptyState({required this.message, required this.actionText, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onTap, child: Text(actionText)),
        ],
      ),
    );
  }
}

class StudyScreen extends StatelessWidget {
  final List<Map<String, dynamic>> cards;
  const StudyScreen({super.key, required this.cards});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const Text('Study'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FlashcardSwiper(cards: cards, labels: const ['Good', 'Maybe', 'Bad']),
        ),
      ),
    );
  }
}

// ---------------------- Local Storage ----------------------
class StudySession {
  final String id;
  final DateTime createdAt;
  final List<Map<String, dynamic>> flashcards;
  final String outline;

  StudySession({required this.id, required this.createdAt, required this.flashcards, required this.outline});

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'flashcards': flashcards,
        'outline': outline,
      };

  static StudySession? fromJson(Map<String, dynamic> j) {
    try {
      return StudySession(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        flashcards: (j['flashcards'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[],
        outline: (j['outline'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class StudyStorage {
  static const String _indexKey = 'sessions_index_v1';

  static Future<List<String>> _getIndex(SharedPreferences prefs) async {
    final list = prefs.getStringList(_indexKey) ?? <String>[];
    return list;
  }

  static Future<void> _setIndex(SharedPreferences prefs, List<String> ids) async {
    await prefs.setStringList(_indexKey, ids);
  }

  static Future<void> saveSession(StudySession s) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await _getIndex(prefs);
    if (!ids.contains(s.id)) ids.insert(0, s.id);
    await _setIndex(prefs, ids);
    await prefs.setString('session_${s.id}', jsonEncode(s.toJson()));
  }

  static Future<List<StudySession>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await _getIndex(prefs);
    final out = <StudySession>[];
    for (final id in ids) {
      final raw = prefs.getString('session_$id');
      if (raw == null) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final s = StudySession.fromJson(map);
        if (s != null) out.add(s);
      } catch (_) {}
    }
    return out;
  }

  static Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await _getIndex(prefs);
    ids.remove(id);
    await _setIndex(prefs, ids);
    await prefs.remove('session_$id');
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<StudySession>> _future;

  @override
  void initState() {
    super.initState();
    _future = StudyStorage.loadAll();
  }

  void _refresh() => setState(() => _future = StudyStorage.loadAll());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    style: IconButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.all(8)),
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Text('Previous Study Packs', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<StudySession>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snap.data ?? const <StudySession>[];
                    if (items.isEmpty) {
                      return const Center(child: Text('No saved study packs', style: TextStyle(color: Colors.white70)));
                    }
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final s = items[i];
                        return Dismissible(
                          key: Key(s.id),
                          background: Container(color: Colors.redAccent),
                          onDismissed: (_) async {
                            await StudyStorage.deleteSession(s.id);
                            _refresh();
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                            ),
                            child: ListTile(
                              title: Text('Study Pack — ${s.createdAt.toLocal()}'),
                              subtitle: Text('${s.flashcards.length} cards', maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PreviewScreen(
                                      originalFiles: const [],
                                      flashcards: s.flashcards,
                                      outline: s.outline,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FlashcardSwiper extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final List<String> labels;
  const FlashcardSwiper({super.key, required this.cards, this.labels = const ['I know it!', 'Maybe know it...', 'I dunno']});

  @override
  State<FlashcardSwiper> createState() => _FlashcardSwiperState();
}

class _FlashcardSwiperState extends State<FlashcardSwiper> {
  late final PageController _controller;
  int _index = 0;
  bool _showBack = false;
  final Map<int, Knowledge> _ratings = {};

  int get _knownCount => _ratings.values.where((r) => r == Knowledge.know).length;
  int get _maybeCount => _ratings.values.where((r) => r == Knowledge.maybe).length;
  int get _dunnoCount => _ratings.values.where((r) => r == Knowledge.dunno).length;

  void _rate(Knowledge k) {
    setState(() {
      _ratings[_index] = k;
    });
    if (_index < widget.cards.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFlip() => setState(() => _showBack = !_showBack);

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Card ${_index + 1} / ${widget.cards.length}',
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            const Text('Tap to flip · Swipe for next', style: TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 360,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) {
              setState(() {
                _index = i;
                _showBack = false;
              });
            },
            itemCount: widget.cards.length,
            itemBuilder: (context, i) {
              final c = widget.cards[i];
              final front = (c['front'] ?? '').toString();
              final back = (c['back'] ?? '').toString();

              return GestureDetector(
                onTap: _toggleFlip,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                _showBack ? 'Answer' : 'Question',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Spacer(),
              Icon(_showBack ? Icons.flip_to_front : Icons.flip, size: 18),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) {
                            final rotate = Tween(begin: _showBack ? 1.0 : -1.0, end: 0.0).animate(anim);
                            return AnimatedBuilder(
                              animation: rotate,
                              child: child,
                              builder: (context, child) {
                                final isUnder = (ValueKey(_showBack) != child!.key);
                                var tilt = (anim.value - 0.5).abs() - 0.5;
                                tilt *= isUnder ? -0.003 : 0.003;
                                final value = 1 - anim.value;
                                return Transform(
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001)
                                    ..rotateY(value * (isUnder ? -1 : 1))
                                    ..setEntry(3, 0, tilt),
                                  alignment: Alignment.centerLeft,
                                  child: child,
                                );
                              },
                            );
                          },
                          child: SingleChildScrollView(
                            key: ValueKey(_showBack),
                            child: Text(
                              _showBack ? back : front,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous',
              onPressed: _index > 0
                  ? () => _controller.previousPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Next',
              onPressed: _index < widget.cards.length - 1
                  ? () => _controller.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Known: ${_knownCount} · Maybe: ${_maybeCount} · Dunno: ${_dunnoCount}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _rate(Knowledge.know),
                icon: const Icon(Icons.check),
                label: Text(widget.labels[0]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _rate(Knowledge.maybe),
                icon: const Icon(Icons.help_outline),
                label: Text(widget.labels[1]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _rate(Knowledge.dunno),
                icon: const Icon(Icons.close),
                label: Text(widget.labels[2]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum Knowledge { know, maybe, dunno }
