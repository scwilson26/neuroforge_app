import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart' show StudySession, StudyStorage;

class ValidationError implements Exception {
  final String code;
  final String message;
  ValidationError(this.code, this.message);
  @override
  String toString() => 'ValidationError($code): $message';
}

class StorageError implements Exception {
  final String message;
  StorageError(this.message);
  @override
  String toString() => 'StorageError: $message';
}

class PackSummary {
  final String id;
  final String title;
  final DateTime createdAt;
  final int cardCount;
  PackSummary({required this.id, required this.title, required this.createdAt, required this.cardCount});

  factory PackSummary.fromSession(StudySession s) =>
      PackSummary(id: s.id, title: s.name, createdAt: s.createdAt, cardCount: s.flashcards.length);
}

class PackBackup {
  final StudySession session;
  final int index; // position in the list/index
  PackBackup(this.session, this.index);
}

String _fmt(DateTime dt) {
  final d = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

class StudyPackRepository {
  static const _migrationFlag = 'sessions_title_migrated_v1';

  Future<void> _migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool(_migrationFlag) ?? false;
    // Idempotent migration using public APIs
    final sessions = await StudyStorage.loadAll();
    for (final s in sessions) {
      if (s.name.trim().isEmpty || s.name.startsWith('Pack ')) {
        final title = 'Study Pack — ${_fmt(s.createdAt)}';
        try {
          await StudyStorage.renameSession(s.id, title);
        } catch (_) {}
      }
    }
    if (!migrated) await prefs.setBool(_migrationFlag, true);
  }

  // Title validation enforced in data layer
  void _validateTitle(String title, {Iterable<StudySession> existing = const [], String? exceptId}) {
    final t = title.trim();
    if (t.isEmpty) throw ValidationError('empty', 'Title cannot be empty');
    if (t.length > 60) throw ValidationError('too_long', 'Title must be 60 characters or fewer');
    bool badEnds(String s) => s.startsWith('.') || s.endsWith('.') || s.startsWith('/') || s.endsWith('/') || s.startsWith('\\') || s.endsWith('\\');
    if (badEnds(t)) throw ValidationError('invalid_chars', 'Title cannot start or end with dots or slashes');
    final lower = t.toLowerCase();
    for (final s in existing) {
      if (exceptId != null && s.id == exceptId) continue;
      if (s.name.toLowerCase() == lower) {
        throw ValidationError('duplicate', 'A pack with this title already exists');
      }
    }
  }

  Future<List<PackSummary>> listPacks() async {
    await _migrateIfNeeded();
    final all = await StudyStorage.loadAll();
    // Sort by createdAt desc (most recent first)
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.map(PackSummary.fromSession).toList(growable: false);
  }

  Future<PackSummary> renamePack(String id, String newTitle) async {
    await _migrateIfNeeded();
    final all = await StudyStorage.loadAll();
    final target = all.where((s) => s.id == id).cast<StudySession?>().firstWhere((e) => e != null, orElse: () => null);
    if (target == null) throw StorageError('Pack not found');
    _validateTitle(newTitle, existing: all, exceptId: id);
    await StudyStorage.renameSession(id, newTitle.trim());
    // Read back to verify write-through
    final after = await StudyStorage.loadAll();
    final updated = after.firstWhere((s) => s.id == id, orElse: () => throw StorageError('Rename did not persist'));
    return PackSummary.fromSession(updated);
  }

  Future<PackBackup> deletePack(String id) async {
    await _migrateIfNeeded();
    final all = await StudyStorage.loadAll();
    final index = all.indexWhere((s) => s.id == id);
    if (index == -1) throw StorageError('Pack not found');
    final session = all[index];
    await StudyStorage.deleteSession(id);
    // Verify deletion
    final after = await StudyStorage.loadAll();
    final stillThere = after.any((s) => s.id == id);
    if (stillThere) throw StorageError('Delete failed');
    return PackBackup(session, index);
  }

  Future<void> restorePack(PackBackup backup) async {
    await StudyStorage.saveSessionAt(backup.session, index: backup.index);
  }
}
