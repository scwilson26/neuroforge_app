import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const SpacedApp());

class SpacedApp extends StatelessWidget {
  const SpacedApp({super.key});

  static const Color tealBg = Color(0xFF0097A7);
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spaced – Study Pack',
      theme: ThemeData(
        scaffoldBackgroundColor: tealBg,
        textTheme: GoogleFonts.poppinsTextTheme().apply(
          bodyColor: white,
          displayColor: white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: tealBg,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.disabled)) return Colors.black54;
              return black;
            }),
            foregroundColor: WidgetStateProperty.all<Color>(white),
            overlayColor: WidgetStateProperty.all<Color>(Colors.white12),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            side: WidgetStateProperty.resolveWith<BorderSide>((states) {
              final color = states.contains(WidgetState.disabled) ? Colors.black26 : black;
              return BorderSide(color: color, width: 1.5);
            }),
            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.disabled)) return Colors.white70;
              return white;
            }),
            foregroundColor: WidgetStateProperty.all<Color>(black),
            overlayColor: WidgetStateProperty.all<Color>(Colors.black12),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            padding: WidgetStateProperty.all(
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

  Future<void> _pickAndPreview() async {
    setState(() {
      _loading = true;
      _status = '';
      _selectedFiles = [];
    });

    final picked = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
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
      final streamed = await req.send();
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
      setState(() {
        _status = 'Network error: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Turn your notes into a study system fast',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: _loading ? null : _pickAndPreview,
                          child: Text(_loading ? 'Working…' : 'Upload Study Notes'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Supports PDF, DOCX, TXT, Images',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LibraryScreen()),
                          ),
                          child: const Text('Previous Study Packs'),
                        ),
                        if (_status.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87)),
                        ]
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
  final Set<int> _showBack = {};
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
        // Share sheet so user can send to Drive/Gmail/etc.
        // Avoid writing to disk; share from memory.
        // ignore: deprecated_member_use
        // Using XFile from share_plus
        await Share.shareXFiles([
          XFile.fromData(bytes, name: 'study_pack.zip', mimeType: 'application/zip'),
        ], text: 'Your study pack is ready!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Study Pack ready')));
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
                  const Text('Preview', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => _tab = PreviewTab.flashcards),
                    child: const Text('Flashcards'),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() => _tab = PreviewTab.outline),
                    child: const Text('Outline'),
                  ),
                  ElevatedButton(
                    onPressed: _downloading || (widget.originalFiles == null || widget.originalFiles!.isEmpty)
                        ? null
                        : _downloadStudyPack,
                    child: Text(_downloading ? 'Preparing…' : 'Download Study Pack'),
                  ),
                  ElevatedButton(
                    onPressed: _goStudy,
                    child: const Text('Study!'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _tab == PreviewTab.flashcards
                    ? _FlashcardList(
                        cards: widget.flashcards,
                        selected: _selected,
                        showBack: _showBack,
                        onToggleSelected: (i, v) => setState(() => _selected[i] = v),
                      )
                    : _OutlineView(text: widget.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlashcardList extends StatelessWidget {
  final List<Map<String, dynamic>> cards;
  final List<bool> selected;
  final Set<int> showBack;
  final void Function(int index, bool value) onToggleSelected;
  const _FlashcardList({required this.cards, required this.selected, required this.showBack, required this.onToggleSelected});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: cards.length,
      itemBuilder: (context, i) {
        final c = cards[i];
        final front = (c['front'] ?? '').toString();
        final back = (c['back'] ?? '').toString();
        final isBack = showBack.contains(i);
        return StatefulBuilder(
          builder: (context, setState) => Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() {
                if (isBack) {
                  showBack.remove(i);
                } else {
                  showBack.add(i);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isBack ? Colors.green.shade600 : Colors.blueGrey.shade700,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(isBack ? 'Answer' : 'Question', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 8),
                          Text(isBack ? back : front, style: const TextStyle(color: Colors.black87)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Checkbox(
                      value: selected[i],
                      onChanged: (v) => onToggleSelected(i, v ?? true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OutlineView extends StatelessWidget {
  final String text;
  const _OutlineView({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Text(text, style: const TextStyle(color: Colors.black87, height: 1.3)),
        ),
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
                  const Text('Study', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: FlashcardSwiper(cards: cards, labels: const ['Good', 'Maybe', 'Bad'])),
            ],
          ),
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
                              color: _showBack ? Colors.green.shade600 : Colors.blueGrey.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _showBack ? 'Answer' : 'Question',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Spacer(),
                          Icon(_showBack ? Icons.flip_to_front : Icons.flip, color: Colors.black45, size: 18),
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
                              style: const TextStyle(color: Colors.black87, height: 1.3),
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
              icon: const Icon(Icons.chevron_left, color: Colors.black87),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Next',
              onPressed: _index < widget.cards.length - 1
                  ? () => _controller.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut)
                  : null,
              icon: const Icon(Icons.chevron_right, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Known: ${_knownCount} · Maybe: ${_maybeCount} · Dunno: ${_dunnoCount}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
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
