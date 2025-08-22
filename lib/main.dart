import 'dart:convert';
import 'dart:async';
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
import 'config.dart';
import 'picker/picker.dart';
import 'picker/types.dart' as pick;
import 'platform/multipart.dart' as mp;
import 'repository.dart' show StudyPackRepository;
import 'http_headers.dart';

void main() => runApp(const SpacedApp());

String _formatDateTime(DateTime dt) {
  final d = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

// Global app activity flags used to guard destructive actions
class AppActivity {
  static final ValueNotifier<bool> isGenerating = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isExporting = ValueNotifier<bool>(false);
  static final ValueNotifier<String?> openPackId = ValueNotifier<String?>(null);
}

Route<T> _fadeSlide<T>(Widget page, BuildContext context, {int ms = 180}) {
  final disable = MediaQuery.of(context).disableAnimations;
  final duration = Duration(milliseconds: disable ? 0 : ms);
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

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
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.all(8),
          ),
        ),
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
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.all(8),
          ),
        ),
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
  final String previewApi = ApiConfig.uri('/preview-study-pack', {'limit': '200'}).toString();
  List<PlatformFile> _selectedFiles = [];
  List<pick.PickedFile> _pickedDisplay = [];
  http.Client? _client;
  bool _cancelled = false;
  int _progressStage = 0; // index into rotating messages
  double _progress = 0.0; // 0..1
  bool _canRetry = false;
  static const Duration _msgInterval = Duration(seconds: 5);
  static const Duration _maxWait = Duration(minutes: 10);
  DateTime? _phaseStart;
  static const List<String> _uploadMsgs = [
    'Uploading…',
    'Still uploading…',
    'Almost there…',
  ];
  static const List<String> _processMsgs = [
    'Parsing',
    'Detecting high-yield',
    'Generating cards',
    'Building outline',
  ];
  Timer? _msgTimer;

  void _startMsgRotation({required bool uploading}) {
    _progressStage = 0;
    _msgTimer?.cancel();
    _msgTimer = Timer.periodic(_msgInterval, (_) {
      if (!_loading) return;
      setState(() {
        final list = uploading ? _uploadMsgs : _processMsgs;
        _progressStage = (_progressStage + 1) % list.length;
      });
    });
  }

  String get _currentMsg => _isUploadingPhase ? _uploadMsgs[_progressStage] : _processMsgs[_progressStage % _processMsgs.length];
  bool get _isUploadingPhase => _phaseStart != null && _progress < 0.6;
  void _setPhaseUploading() {
    _phaseStart = DateTime.now();
    _startMsgRotation(uploading: true);
  }
  void _setPhaseProcessing() {
    _phaseStart = DateTime.now();
    _startMsgRotation(uploading: false);
  }
  void _bumpProgressToward(double target, {double step = 0.02}) {
    if (_progress < target) {
      _progress = (_progress + step).clamp(0.0, target);
    }
  }

  Future<void> _pickAndPreview() async {
    setState(() {
      _loading = true;
      _status = '';
      _selectedFiles = [];
      _cancelled = false;
      _canRetry = false;
      _progress = 0.0;
    });
  AppActivity.isGenerating.value = true;
    _setPhaseUploading();

  final picker = getNotesPicker();
  final pickedFiles = await picker.pickMultiple(allowedExtensions: const ['pdf', 'docx', 'txt', 'jpg', 'jpeg', 'png']);
  if (pickedFiles == null || pickedFiles.isEmpty) {
      setState(() {
        _loading = false;
        _status = 'No files selected.';
      });
      return;
    }
  // Enforce 10 MB per file limit
  const int maxBytes = 10 * 1024 * 1024;
  final filtered = pick.filterByMaxSize(pickedFiles, maxBytes);
  _pickedDisplay = filtered.accepted;
  if (filtered.rejected.isNotEmpty) {
    final names = filtered.rejected.map((r) => r.name).take(3).join(', ');
    _status = filtered.rejected.length == 1
      ? '“${names}” is larger than 10 MB'
      : '${filtered.rejected.length} files are larger than 10 MB${names.isNotEmpty ? ' (e.g., $names)' : ''}';
  }
  // Convert accepted to PlatformFile shape for upload layer
  _selectedFiles = _pickedDisplay
    .map((f) => PlatformFile(name: f.name, size: f.size, bytes: f.bytes, path: f.path))
    .toList();

  final req = http.MultipartRequest('POST', Uri.parse(previewApi));
  req.headers.addAll(await HttpHeadersHelper.previewHeaders());
    await mp.addFilesToMultipart(req, _selectedFiles);

    try {
      _client = http.Client();
      // Simulate upload progress while waiting for server to accept
      final uploadTicker = Timer.periodic(const Duration(milliseconds: 600), (_) {
        if (!_loading) return;
        setState(() => _bumpProgressToward(0.6, step: 0.02));
      });
      final streamed = await _client!.send(req);
      uploadTicker.cancel();
      final res = await http.Response.fromStream(streamed);
      if (_cancelled) return;
      if (res.statusCode == 200) {
        // Immediate preview ready
        setState(() => _progress = 1.0);
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        await _openPreviewFromBody(body);
      } else if (res.statusCode == 202 || res.statusCode == 201) {
        // Accepted -> poll
        final body = jsonDecode(res.body.isNotEmpty ? res.body : '{}') as Map<String, dynamic>;
        final jobId = (body['job_id'] ?? body['jobId'] ?? body['id'] ?? '').toString();
        if (jobId.isEmpty) {
          setState(() {
            _status = 'Upload accepted but no job id returned.';
            _canRetry = true;
          });
        } else {
          _setPhaseProcessing();
          setState(() => _bumpProgressToward(0.7));
          await _pollUntilReady(jobId);
        }
      } else if (res.statusCode == 413) {
        setState(() {
          _status = 'Upload too large. Please keep files under 10 MB each.';
          _canRetry = true;
        });
      } else if (res.statusCode == 415) {
        setState(() {
          _status = 'Unsupported file type. Use PDF, DOCX, TXT, JPG, or PNG.';
          _canRetry = true;
        });
      } else if (res.statusCode == 429) {
        setState(() {
          _status = 'Server busy. Please retry in a moment.';
          _canRetry = true;
        });
      } else if (res.statusCode >= 500 && res.statusCode < 600) {
        setState(() {
          _status = 'Server error (${res.statusCode}). Please retry.';
          _canRetry = true;
        });
      } else {
        setState(() {
          _status = 'Error ${res.statusCode}: ${res.reasonPhrase ?? 'Request failed'}';
          _canRetry = true;
        });
      }
    } catch (e) {
      if (!_cancelled) {
        setState(() {
          _status = 'Network error: $e';
          _canRetry = true;
        });
      }
    } finally {
      _client?.close();
      if (mounted) {
        // Keep overlay open if we can retry
        if (!_canRetry) setState(() => _loading = false);
      }
      AppActivity.isGenerating.value = false;
      _msgTimer?.cancel();
    }
  }

  Future<void> _pollUntilReady(String jobId) async {
    final start = DateTime.now();
    Duration backoff = const Duration(seconds: 2);
    while (true) {
      if (!mounted || _cancelled) return;
      if (DateTime.now().difference(start) > _maxWait) {
        setState(() {
          _status = 'Taking longer than expected. Please retry later.';
          _canRetry = true;
        });
        return;
      }
      try {
        // Poll every ~5s
        await Future.delayed(const Duration(seconds: 5));
        if (_cancelled) return;
  final uri = ApiConfig.uri('/preview-study-pack', {'job_id': jobId, 'limit': '200'});
  final res = await http.get(uri, headers: await HttpHeadersHelper.previewHeaders());
        if (_cancelled) return;
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          if (body.containsKey('flashcards')) {
            setState(() => _progress = 1.0);
            await _openPreviewFromBody(body);
            return;
          }
          // Not ready but 200: bump progress a bit
          setState(() => _bumpProgressToward(0.95));
          continue;
        } else if (res.statusCode == 202) {
          // Still processing
          setState(() => _bumpProgressToward(0.95));
          continue;
        } else if (res.statusCode == 429 || (res.statusCode >= 500 && res.statusCode < 600)) {
          await Future.delayed(backoff);
          backoff = Duration(milliseconds: (backoff.inMilliseconds * 1.6).toInt().clamp(2000, 20000));
          continue;
        } else if (res.statusCode == 413) {
          setState(() {
            _status = 'Upload too large. Please keep files under 10 MB each.';
            _canRetry = true;
          });
          return;
        } else if (res.statusCode == 415) {
          setState(() {
            _status = 'Unsupported file type. Use PDF, DOCX, TXT, JPG, or PNG.';
            _canRetry = true;
          });
          return;
        } else {
          setState(() {
            _status = 'Error ${res.statusCode}: ${res.reasonPhrase ?? ''}';
            _canRetry = true;
          });
          return;
        }
      } catch (e) {
        if (_cancelled) return;
        setState(() {
          _status = 'Network error while polling: $e';
          _canRetry = true;
        });
        return;
      }
    }
  }

  Future<void> _openPreviewFromBody(Map<String, dynamic> body) async {
    final cards = (body['flashcards'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final outline = (body['outline'] ?? '').toString();
    final now = DateTime.now();
    final defaultName = 'Study Pack — ${_formatDateTime(now)}';
    final session = StudySession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: defaultName,
      createdAt: now,
      flashcards: cards,
      outline: outline,
    );
    await StudyStorage.saveSession(session);
    if (!mounted || _cancelled) return;
    setState(() {
      _loading = false;
      _canRetry = false;
    });
    Navigator.of(context).push(_fadeSlide(
      PreviewScreen(
        originalFiles: _selectedFiles,
        flashcards: cards,
        outline: outline,
        sessionId: session.id,
        sessionName: defaultName,
      ),
      context,
    ));
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
                      if (_pickedDisplay.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Selected files', textAlign: TextAlign.center, style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: Scrollbar(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _pickedDisplay.length,
                              itemBuilder: (context, i) {
                                final f = _pickedDisplay[i];
                                final mb = (f.size / (1024 * 1024)).toStringAsFixed(1);
                                return Text('• ${f.name} — ${mb} MB', textAlign: TextAlign.center, style: textTheme.bodySmall);
                              },
                            ),
                          ),
                        ),
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
                                Text('Preparing preview…', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                                const SizedBox(height: 8),
                                AnimatedSwitcher(
                                  duration: Duration(milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 180),
                                  child: Text(
                                    _currentMsg,
                                    key: ValueKey('msg$_progressStage'),
                                    style: textTheme.bodySmall,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    if (_canRetry)
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            // retry with previous selection
                                            if (_pickedDisplay.isEmpty) {
                                              setState(() { _loading = false; });
                                              return;
                                            }
                                            setState(() {
                                              _status = '';
                                              _canRetry = false;
                                              _cancelled = false;
                                              _progress = 0.0;
                                            });
                                            _pickAndPreview();
                                          },
                                          child: const Text('Retry'),
                                        ),
                                      ),
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () {
                                          _cancelled = true;
                                          _client?.close();
                                          if (mounted) setState(() => _loading = false);
                                          // Ensure we end up on Home if invoked elsewhere
                                          if (Navigator.of(context).canPop()) {
                                            Navigator.of(context).popUntil((r) => r.isFirst);
                                          }
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_status.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(_status, style: textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                                ]
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
  final String? sessionId; // when opened from Library
  final String? sessionName; // display name
  const PreviewScreen({super.key, this.originalFiles, required this.flashcards, required this.outline, this.sessionId, this.sessionName});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

enum PreviewTab { flashcards, outline }

class _PreviewScreenState extends State<PreviewScreen> {
  PreviewTab _tab = PreviewTab.flashcards;
  late List<ValueNotifier<bool>> _selected;
  final ValueNotifier<int> _selectedCountVN = ValueNotifier<int>(0);
  bool _downloading = false;
  bool _bulkPulse = false;
  String? _sessionName;

  @override
  void initState() {
    super.initState();
    // Mark open pack if we have a session id (opened from Library)
    if (widget.sessionId != null) {
      AppActivity.openPackId.value = widget.sessionId;
    }
    _selected = List.generate(widget.flashcards.length, (_) => ValueNotifier<bool>(true));
    _selectedCountVN.value = widget.flashcards.length;
  _sessionName = widget.sessionName;
  }

  @override
  void dispose() {
    for (final vn in _selected) {
      vn.dispose();
    }
    _selectedCountVN.dispose();
    if (widget.sessionId != null && AppActivity.openPackId.value == widget.sessionId) {
      AppActivity.openPackId.value = null;
    }
    super.dispose();
  }

  Future<void> _downloadStudyPack() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    AppActivity.isExporting.value = true;
    try {
  final req = http.MultipartRequest('POST', ApiConfig.uri('/generate-study-pack'));
  req.headers.addAll(await HttpHeadersHelper.zipHeaders());
  final files = widget.originalFiles ?? const <PlatformFile>[];
  await mp.addFilesToMultipart(req, files);
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final bytes = res.bodyBytes;
        final title = (widget.sessionName ?? 'Study Pack').trim();
        String sanitize(String s) {
          final cleaned = s.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_').replaceAll(RegExp(r'_+'), '_').trim();
          return cleaned.isEmpty ? 'study_pack' : (cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned);
        }
        final baseName = sanitize(title);
        if (kIsWeb) {
          await FileSaver.instance.saveFile(
            name: baseName,
            bytes: bytes,
            ext: 'zip',
            mimeType: MimeType.other,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved ${baseName}.zip')));
          }
        } else {
          try {
            await Share.shareXFiles([
              XFile.fromData(bytes, name: '${baseName}.zip', mimeType: 'application/zip'),
            ], text: 'Your study pack is ready: ${title}');
          } catch (_) {
            await FileSaver.instance.saveFile(
              name: baseName,
              bytes: bytes,
              ext: 'zip',
              mimeType: MimeType.other,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved ${baseName}.zip')));
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
      AppActivity.isExporting.value = false;
    }
  }

  void _goStudy() {
    final kept = <Map<String, dynamic>>[];
    for (var i = 0; i < widget.flashcards.length; i++) {
  if (_selected[i].value) kept.add(widget.flashcards[i]);
    }
    if (kept.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one card')));
      return;
    }
  Navigator.of(context).push(_fadeSlide(StudyScreen(cards: kept, title: widget.sessionName, sessionId: widget.sessionId), context));
  }

  int get _selectedCount => _selectedCountVN.value;

  void _setTab(PreviewTab t) {
    setState(() => _tab = t);
    // Accessibility: Announce tab change
    final label = t == PreviewTab.flashcards ? 'Flashcards' : 'Outline';
    SemanticsService.announce(label, TextDirection.ltr);
  }

  void _bulkSelect(bool value) {
    HapticFeedback.lightImpact();
    for (var i = 0; i < _selected.length; i++) {
      _selected[i].value = value;
    }
    _selectedCountVN.value = value ? _selected.length : 0;
    if (value) {
      setState(() => _bulkPulse = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() => _bulkPulse = false);
      });
    }
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
            AnimatedSwitcher(
              duration: Duration(milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 180),
              child: _selectedCount > 0
                  ? Row(
                      key: ValueKey('sel-${_selectedCount}') ,
                      children: [
                        AnimatedOpacity(
                          duration: Duration(milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 150),
                          opacity: _bulkPulse ? 1 : 0,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.check_circle, size: 16),
                          ),
                        ),
                        Text(
                          '${_selectedCount} selected',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75),
                              ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          if (widget.sessionId != null) ...[
            IconButton(
              tooltip: 'Rename pack',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _renameCurrentPack,
            ),
            IconButton(
              tooltip: 'Delete pack',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteCurrentPack,
            ),
          ],
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
            child: Semantics(
              container: true,
              label: 'Preview mode',
              hint: 'Switch between Flashcards and Outline',
              value: _tab == PreviewTab.flashcards ? 'Flashcards' : 'Outline',
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
                child: Semantics(
                  button: true,
                  label: 'Download study pack',
                  hint: 'Share or save a ZIP of your study materials',
                  child: ElevatedButton(
                    onPressed: _downloading || (widget.originalFiles == null || widget.originalFiles!.isEmpty)
                        ? null
                        : _downloadStudyPack,
                    child: Text(_downloading ? 'Preparing…' : 'Download study pack'),
                  ),
                ),
              ),
        const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Study now',
                  hint: 'Open flashcards in study mode',
                  child: OutlinedButton(
                    onPressed: _selectedCount == 0 ? null : _goStudy,
                    child: const Text('Study now'),
                  ),
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
    return ListView.builder(
      itemCount: cards.length,
      itemBuilder: (context, i) {
        final c = cards[i];
        final front = (c['front'] ?? '').toString();
        final back = (c['back'] ?? '').toString();
        return ValueListenableBuilder<bool>(
          valueListenable: _selected[i],
          builder: (context, checked, _) => Column(
            children: [
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                title: Text(front, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                trailing: Checkbox(
                  value: checked,
                  onChanged: (v) {
                    final nv = v ?? true;
                    _selected[i].value = nv;
                    _selectedCountVN.value += nv ? 1 : -1;
                  },
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Answer', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(back, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
              const Divider(height: 1),
            ],
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
    final sections = _parseOutlineSections(text);
    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      );
    }
    return ListView.separated(
      itemCount: sections.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = sections[i];
        return ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text(s.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(s.body, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        );
      },
    );
  }

  List<_OutlineSection> _parseOutlineSections(String content) {
    final lines = content.split('\n');
    final List<_OutlineSection> out = [];
    String? currentTitle;
    final body = StringBuffer();
    bool hasBody = false;
    bool isHeading(String line) {
      final t = line.trim();
      if (t.isEmpty) return false;
      if (RegExp(r'^#{1,6}\s').hasMatch(t)) return true;
      if (RegExp(r'^[0-9]+[\.)]\s').hasMatch(t)) return true;
      if (t.endsWith(':') && t.length < 80) return true;
      return false;
    }
    void pushSection() {
      if (currentTitle != null) {
        out.add(_OutlineSection(currentTitle!, body.toString().trim()));
      }
      currentTitle = null;
      body.clear();
      hasBody = false;
    }
    for (final raw in lines) {
      if (isHeading(raw)) {
        pushSection();
        var t = raw.trim();
        t = t.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
        t = t.replaceFirst(RegExp(r'^[0-9]+[\.)]\s*'), '');
        if (t.endsWith(':')) t = t.substring(0, t.length - 1).trim();
        currentTitle = t;
      } else {
        if (hasBody) body.writeln();
        body.write(raw);
        hasBody = true;
      }
    }
    pushSection();
    return out;
  }


  Future<void> _renameCurrentPack() async {
    if (widget.sessionId == null) return;
    final controller = TextEditingController(text: _sessionName ?? '');
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Rename pack'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(hintText: 'Enter name', errorText: error),
          onSubmitted: (_) => Navigator.of(context).pop('save'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop('cancel'), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop('save'), child: const Text('Save')),
        ],
      ),
    );
    if (result != 'save') return;
    final name = controller.text.trim();
    if (name.isEmpty || name.length > 60) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid name')));
      return;
    }
    try {
      await StudyStorage.renameSession(widget.sessionId!, name);
      setState(() => _sessionName = name);
      SemanticsService.announce('Renamed to $name', TextDirection.ltr);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rename failed')));
    }
  }

  Future<void> _deleteCurrentPack() async {
    if (widget.sessionId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pack?'),
        content: const Text("This will remove it from your device. You can’t undo this."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await StudyStorage.deleteSession(widget.sessionId!);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete failed')));
      }
    }
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

class StudyScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final String? title;
  final String? sessionId;
  const StudyScreen({super.key, required this.cards, this.title, this.sessionId});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late String _title;

  @override
  void initState() {
    super.initState();
    _title = widget.title ?? 'Study';
  }

  Future<void> _promptRename() async {
    final controller = TextEditingController(text: _title);
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename pack'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 60,
                decoration: InputDecoration(
                  hintText: 'Enter name',
                  errorText: error,
                ),
                onSubmitted: (_) => Navigator.of(context).pop('save'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop('cancel'), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(context).pop('save'), child: const Text('Save')),
          ],
        );
      },
    );

    if (result != 'save') return;
    final name = controller.text.trim();
    if (name.isEmpty || name.length > 60 || name.startsWith('.') || name.endsWith('.') || name.startsWith('/') || name.endsWith('/') || name.startsWith('\\') || name.endsWith('\\')) {
      // Re-open with inline error
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Rename pack'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: controller.text),
                autofocus: true,
                maxLength: 60,
                decoration: const InputDecoration(
                  hintText: 'Enter name',
                  errorText: 'Name can’t be empty',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ],
        ),
      );
      return;
    }

    final old = _title;
    setState(() => _title = name);
    try {
      final id = widget.sessionId;
      if (id != null && id.isNotEmpty) {
        await StudyStorage.renameSession(id, name);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Renamed to "$name"')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _title = old);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rename failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Tooltip(
          message: _title,
          preferBelow: false,
          child: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _promptRename,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FlashcardSwiper(cards: widget.cards, labels: const ['Good', 'Maybe', 'Bad']),
        ),
      ),
    );
  }
}

// ---------------------- Local Storage ----------------------
class StudySession {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<Map<String, dynamic>> flashcards;
  final String outline;

  StudySession({required this.id, required this.name, required this.createdAt, required this.flashcards, required this.outline});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'flashcards': flashcards,
        'outline': outline,
      };

  static StudySession? fromJson(Map<String, dynamic> j) {
    try {
      final id = j['id'] as String;
      final created = DateTime.parse(j['createdAt'] as String);
      final nameRaw = j['name'];
    final name = (nameRaw == null || (nameRaw as Object).toString().trim().isEmpty)
      ? 'Study Pack — ${_formatDateTime(created)}'
          : nameRaw.toString();
      final flashcards = (j['flashcards'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
      final outline = (j['outline'] ?? '').toString();
      return StudySession(id: id, name: name, createdAt: created, flashcards: flashcards, outline: outline);
    } catch (_) {
      return null;
    }
  }
}

class _OutlineSection {
  final String title;
  final String body;
  _OutlineSection(this.title, this.body);
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

  static Future<void> saveSessionAt(StudySession s, {int? index}) async {
    final prefs = await SharedPreferences.getInstance();
    var ids = await _getIndex(prefs);
    ids.remove(s.id);
    if (index == null || index < 0 || index > ids.length) {
      ids.insert(0, s.id);
    } else {
      ids.insert(index, s.id);
    }
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

  static Future<void> renameSession(String id, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('session_$id');
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map['name'] = newName;
      await prefs.setString('session_$id', jsonEncode(map));
    } catch (_) {}
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final FocusNode _listFocusNode = FocusNode(debugLabel: 'library_list');
  bool _loading = true;
  List<StudySession> _items = [];
  bool _selectMode = false;
  final Set<String> _selected = <String>{};
  StudySession? _recentlyDeleted;
  int _recentlyDeletedIndex = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _listFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
  // Run idempotent migration (titles, etc.) without altering UI data shape
  try { await StudyPackRepository().listPacks(); } catch (_) {}
  final list = await StudyStorage.loadAll();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  void _exitSelection() {
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
    FocusScope.of(context).requestFocus(_listFocusNode);
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  bool _nameExists(String name, {String? exceptId}) {
    final lower = name.toLowerCase();
    for (final s in _items) {
      if (exceptId != null && s.id == exceptId) continue;
      if (s.name.toLowerCase() == lower) return true;
    }
    return false;
  }

  Future<void> _promptRename(StudySession s) async {
    final controller = TextEditingController(text: s.name);
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename pack'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 60,
                decoration: InputDecoration(
                  hintText: 'Enter name',
                  errorText: error,
                ),
                onSubmitted: (_) => Navigator.of(context).pop('save'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop('cancel'), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(context).pop('save'), child: const Text('Save')),
          ],
        );
      },
    );

    if (result == 'save') {
      String name = controller.text.trim();
      bool invalid = name.isEmpty || name.length > 60 ||
          name.startsWith('.') || name.endsWith('.') ||
          name.startsWith('/') || name.endsWith('/') ||
          name.startsWith('\\') || name.endsWith('\\') ||
          _nameExists(name, exceptId: s.id);
      if (invalid) {
        final dup = _nameExists(name, exceptId: s.id);
        error = dup ? "Name already exists" : "Name can’t be empty";
        // Reopen dialog with inline error
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('Rename pack'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: TextEditingController(text: controller.text),
                    autofocus: true,
                    maxLength: 60,
                    decoration: InputDecoration(
                      hintText: 'Enter name',
                      errorText: error,
                    ),
                    onSubmitted: (_) => Navigator.of(context).pop(),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                TextButton(onPressed: () async {
                  Navigator.of(context).pop();
                  await _promptRename(s);
                }, child: const Text('Save')),
              ],
            );
          },
        );
        return;
      }
      final oldName = s.name;
      // Optimistic update
      setState(() {
        final idx = _items.indexWhere((e) => e.id == s.id);
        if (idx != -1) {
          _items[idx] = StudySession(
            id: s.id,
            name: name,
            createdAt: s.createdAt,
            flashcards: s.flashcards,
            outline: s.outline,
          );
        }
      });
      try {
        await StudyStorage.renameSession(s.id, name);
        SemanticsService.announce('Renamed to $name', TextDirection.ltr);
      } catch (e) {
        // Revert
        setState(() {
          final idx = _items.indexWhere((e) => e.id == s.id);
          if (idx != -1) {
            _items[idx] = StudySession(
              id: s.id,
              name: oldName,
              createdAt: s.createdAt,
              flashcards: s.flashcards,
              outline: s.outline,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rename failed')));
      }
      FocusScope.of(context).requestFocus(_listFocusNode);
    } else {
      FocusScope.of(context).requestFocus(_listFocusNode);
    }
  }

  Future<bool> _confirmDeleteDialog({int count = 1}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pack?'),
        content: const Text("This will remove it from your device. You can’t undo this."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return res == true;
  }

  void _deleteSingle(StudySession s, int index) async {
    if (AppActivity.isGenerating.value || AppActivity.isExporting.value) return;
    if (AppActivity.openPackId.value == s.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Close the pack before deleting.')));
      return;
    }
    final ok = await _confirmDeleteDialog();
    if (!ok) return;

    setState(() {
      _recentlyDeleted = s;
      _recentlyDeletedIndex = index;
      _items.removeAt(index);
    });
    await StudyStorage.deleteSession(s.id);
    SemanticsService.announce('Deleted', TextDirection.ltr);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Pack deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final toRestore = _recentlyDeleted;
            final idx = _recentlyDeletedIndex;
            if (toRestore == null || idx < 0) return;
            setState(() {
              _items.insert(idx, toRestore);
            });
            await StudyStorage.saveSessionAt(toRestore, index: idx);
            SemanticsService.announce('Restored', TextDirection.ltr);
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    // Prevent delete if any selected is open or while busy
    if (AppActivity.isGenerating.value || AppActivity.isExporting.value) return;
    final openId = AppActivity.openPackId.value;
    if (openId != null && _selected.contains(openId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Close the pack before deleting.')));
      return;
    }
    final ok = await _confirmDeleteDialog(count: _selected.length);
    if (!ok) return;
    final ids = Set<String>.from(_selected);
    final removed = <int, StudySession>{};
    setState(() {
      for (int i = _items.length - 1; i >= 0; i--) {
        final s = _items[i];
        if (ids.contains(s.id)) {
          removed[i] = s;
          _items.removeAt(i);
        }
      }
      _selectMode = false;
      _selected.clear();
    });
    for (final s in removed.values) {
      await StudyStorage.deleteSession(s.id);
    }
    SemanticsService.announce('Deleted', TextDirection.ltr);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(removed.length == 1 ? 'Pack deleted' : 'Packs deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            // Restore in original positions order
            final entries = removed.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
            for (final e in entries) {
              setState(() {
                _items.insert(e.key, e.value);
              });
              await StudyStorage.saveSessionAt(e.value, index: e.key);
            }
            SemanticsService.announce('Restored', TextDirection.ltr);
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: _selectMode
            ? Text('${_selected.length} selected')
            : const Text('Previous packs', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: _selectMode
            ? [
                IconButton(
                  tooltip: 'Rename',
                  onPressed: _selected.length == 1
                      ? () {
                          final id = _selected.first;
                          final s = _items.firstWhere((e) => e.id == id);
                          _promptRename(s).then((_) => _exitSelection());
                        }
                      : null,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: _selected.isNotEmpty ? _deleteSelected : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('No previous packs yet', style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8))),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Upload notes'),
                          ),
                        ],
                      ),
                    )
                  : Focus(
                      focusNode: _listFocusNode,
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = _items[i];
                          final selected = _selected.contains(s.id);
                          return Dismissible(
                            key: Key(s.id),
                            direction: _selectMode ? DismissDirection.none : DismissDirection.horizontal,
                            background: Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(children: [Icon(Icons.edit_outlined, color: theme.colorScheme.primary), const SizedBox(width: 8), const Text('Rename')]),
                            ),
                            secondaryBackground: Container(
                              color: theme.colorScheme.errorContainer,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [const Text('Delete'), const SizedBox(width: 8), Icon(Icons.delete_outline, color: theme.colorScheme.error)]),
                            ),
                            confirmDismiss: (dir) async {
                              if (AppActivity.isGenerating.value || AppActivity.isExporting.value || AppActivity.openPackId.value == s.id) {
                                if (dir == DismissDirection.endToStart) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Close the pack before deleting.')));
                                }
                                return false;
                              }
                              if (dir == DismissDirection.startToEnd) {
                                // Swipe right -> Rename
                                await _promptRename(s);
                                return false;
                              } else if (dir == DismissDirection.endToStart) {
                                // Swipe left -> Delete (confirm)
                                final ok = await _confirmDeleteDialog();
                                return ok;
                              }
                              return false;
                            },
                            onDismissed: (dir) async {
                              // Only delete here after confirmDismiss returned true
                              _recentlyDeleted = s;
                              _recentlyDeletedIndex = i;
                              setState(() {
                                _items.removeAt(i);
                              });
                              await StudyStorage.deleteSession(s.id);
                              SemanticsService.announce('Deleted', TextDirection.ltr);
                              final messenger = ScaffoldMessenger.of(context);
                              messenger.clearSnackBars();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: const Text('Pack deleted'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () async {
                                      final toRestore = _recentlyDeleted;
                                      final idx = _recentlyDeletedIndex;
                                      if (toRestore == null || idx < 0) return;
                                      setState(() {
                                        _items.insert(idx, toRestore);
                                      });
                                      await StudyStorage.saveSessionAt(toRestore, index: idx);
                                      SemanticsService.announce('Restored', TextDirection.ltr);
                                    },
                                  ),
                                  duration: const Duration(seconds: 6),
                                ),
                              );
                            },
                            child: ListTile(
                              onLongPress: () {
                                setState(() {
                                  _selectMode = true;
                                  _selected.clear();
                                  _selected.add(s.id);
                                });
                              },
                              onTap: _selectMode
                                  ? () => _toggleSelect(s.id)
          : () {
                                      Navigator.of(context).push(_fadeSlide(
                                        PreviewScreen(
                                          originalFiles: const [],
                                          flashcards: s.flashcards,
                                          outline: s.outline,
            sessionId: s.id,
                                        ),
                                        context,
                                      ));
                                    },
                              leading: _selectMode
                                  ? Checkbox(
                                      value: selected,
                                      onChanged: (_) => _toggleSelect(s.id),
                                    )
                                  : null,
                              title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_formatDateTime(s.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.75))),
                                  Text('${s.flashcards.length} cards', style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.75))),
                                ],
                              ),
                              trailing: _selectMode
                                  ? null
                                  : PopupMenuButton<String>(
                                      onSelected: (v) {
                                        if (v == 'rename') _promptRename(s);
                                        if (v == 'delete') _deleteSingle(s, i);
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'rename', child: Text('Rename')),
                                        PopupMenuItem(
                                          value: 'delete',
                                          enabled: !(AppActivity.isGenerating.value || AppActivity.isExporting.value || AppActivity.openPackId.value == s.id),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
      floatingActionButton: _selectMode
          ? FloatingActionButton.extended(
              onPressed: _exitSelection,
              label: const Text('Done'),
              icon: const Icon(Icons.check),
            )
          : null,
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
