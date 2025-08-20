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
        // Outlined buttons: white background, black text, black border
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

class FrontPage extends StatelessWidget {
  const FrontPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        centerTitle: true,
        title: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Stack(
              children: [
                Text(
                  'Spaced',
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
                const Text(
                  'Spaced',
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
                        const Text(
                          'Welcome to Spaced. Turn your notes into flashcards instantly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const UploadPage()),
                            );
                          },
                          child: const Text('Upload Study Notes'),
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

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});
  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  bool _loading = false;
  String _status = 'Pick files and generate flashcards.';
  final String api = 'http://10.0.2.2:8000/preview-study-pack?limit=200';
  List<Map<String, dynamic>> _flashcards = const [];
  String? _outline;

  // Keep text strictly white/black; default is white on teal.
  Color get _statusColor {
    return Colors.black;
  }

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
                  'Spaced',
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
                  'Spaced',
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
        child: SingleChildScrollView(
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
                      ],
                    ),
                  ),

                  // Flashcards list (if any)
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
                          Text(
                            'Flashcards (${_flashcards.length})',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // One-at-a-time flashcards with flip + swipe
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

class FlashcardTile extends StatefulWidget {
  final int index;
  final String front;
  final String back;

  const FlashcardTile({super.key, required this.index, required this.front, required this.back});

  @override
  State<FlashcardTile> createState() => _FlashcardTileState();
}

class _FlashcardTileState extends State<FlashcardTile> {
  bool _showBack = false;

  void _toggle() => setState(() => _showBack = !_showBack);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _showBack ? Colors.green.shade600 : Colors.blueGrey.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _showBack ? 'Answer' : 'Question',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  Icon(_showBack ? Icons.visibility_off : Icons.visibility, color: Colors.black54, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
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
                        child: child,
                        alignment: Alignment.centerLeft,
                      );
                    },
                  );
                },
                child: Text(
                  _showBack ? widget.back : widget.front,
                  key: ValueKey(_showBack),
                  style: const TextStyle(color: Colors.black87),
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

  const FlashcardSwiper({super.key, required this.cards});

  @override
  State<FlashcardSwiper> createState() => _FlashcardSwiperState();
}

class _FlashcardSwiperState extends State<FlashcardSwiper> {
  late final PageController _controller;
  int _index = 0;
  bool _showBack = false;

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
    // Safety: handle empty
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
                _showBack = false; // reset on new card
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
      ],
    );
  }
}
