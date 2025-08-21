import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

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
      home: const FrontPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FrontPage extends StatefulWidget {
  const FrontPage({super.key});
  @override
  State<FrontPage> createState() => _FrontPageState();
}

class _FrontPageState extends State<FrontPage> {
  bool _loading = false;
  String _status = 'Pick files and generate flashcards.';
  final String api = 'http://10.0.2.2:8000/preview-study-pack?limit=200';
  List<Map<String, dynamic>> _flashcards = const [];
  String? _outline;

  Color get _statusColor => Colors.black;

  Future<void> _pickUploadGenerate() async {
    setState(() {
      _loading = true;
      _status = 'Picking files…';
      _flashcards = const [];
      _outline = null;
    });

    final picked = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (picked == null || picked.files.isEmpty) {
      setState(() {
        _loading = false;
        _status = 'No files selected.';
      });
      return;
    }

    setState(() => _status = 'Uploading & generating flashcards…');

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
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final cards = (body['flashcards'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final outline = body['outline'] as String?;
        setState(() {
          _flashcards = cards;
          _outline = outline;
          _status = 'Generated ${cards.length} flashcards.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'The future of learning — fast, efficient, AI-powered.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                    const SizedBox(height: 24),
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
                        ],
                      ),
                    ),
                    if (_flashcards.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Flashcards',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FlashcardSwiper(cards: _flashcards),
                          ],
                        ),
                      ),
                    ],
                    if (_outline != null && _outline!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (_) {
                              return DraggableScrollableSheet(
                                initialChildSize: 0.8,
                                expand: false,
                                builder: (context, controller) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: ListView(
                                      controller: controller,
                                      children: [
                                        const Text('Outline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black)),
                                        const SizedBox(height: 12),
                                        Text(_outline!, style: const TextStyle(color: Colors.black87)),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                        child: const Text('View Outline'),
                      ),
                    ],
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

class FlashcardSwiper extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  const FlashcardSwiper({super.key, required this.cards});

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
                label: const Text('I know it!'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _rate(Knowledge.maybe),
                icon: const Icon(Icons.help_outline),
                label: const Text('Maybe know it...'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _rate(Knowledge.dunno),
                icon: const Icon(Icons.close),
                label: const Text('I dunno'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum Knowledge { know, maybe, dunno }
