import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neuroforge_app/main.dart';
import 'package:neuroforge_app/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<StudySession> _makeSession({required String id, String? name, int cards = 3}) async {
    final s = StudySession(
      id: id,
      name: name ?? 'Study Pack — 2025-08-22 10:00',
      createdAt: DateTime(2025, 8, 22, 10, 0),
      flashcards: List.generate(cards, (i) => {'front': 'Q$i', 'back': 'A$i'}),
      outline: 'Outline',
    );
    await StudyStorage.saveSession(s);
    return s;
  }

  test('listPacks sorts by createdAt desc and includes counts', () async {
    final repo = StudyPackRepository();
    await _makeSession(id: '1', name: 'A', cards: 2);
    await _makeSession(id: '2', name: 'B', cards: 5);
    // Change createdAt of the first to be newer
    final newer = StudySession(id: '1', name: 'A', createdAt: DateTime(2025, 8, 23, 9, 0), flashcards: [{'front':'x','back':'y'}], outline: 'O');
    await StudyStorage.saveSession(newer);

    final list = await repo.listPacks();
    expect(list.first.id, '1');
    expect(list.first.cardCount, 1);
  });

  test('renamePack enforces validation and write-through', () async {
    final repo = StudyPackRepository();
  await _makeSession(id: '1', name: 'Alpha');
  await _makeSession(id: '2', name: 'Beta');

    // Duplicate name error
    expect(
      () => repo.renamePack('1', 'beta'),
      throwsA(isA<ValidationError>()),
    );

    // Empty
    expect(() => repo.renamePack('1', '  '), throwsA(isA<ValidationError>()));

    // Too long
    expect(() => repo.renamePack('1', 'x'*61), throwsA(isA<ValidationError>()));

    // Invalid ends
    expect(() => repo.renamePack('1', '/foo'), throwsA(isA<ValidationError>()));
    expect(() => repo.renamePack('1', 'foo/'), throwsA(isA<ValidationError>()));
    expect(() => repo.renamePack('1', '.foo'), throwsA(isA<ValidationError>()));
    expect(() => repo.renamePack('1', 'foo.'), throwsA(isA<ValidationError>()));

    // Happy path
    final updated = await repo.renamePack('1', 'Gamma');
    expect(updated.title, 'Gamma');
    final list = await repo.listPacks();
    expect(list.any((p) => p.title == 'Gamma'), isTrue);
  });

  test('deletePack returns backup and restorePack restores it', () async {
    final repo = StudyPackRepository();
  await _makeSession(id: '1', name: 'Alpha');
    final backup = await repo.deletePack('1');
    expect(backup.session.id, '1');

    // Should be gone
    final listAfter = await repo.listPacks();
    expect(listAfter.any((p) => p.id == '1'), isFalse);

    // Restore
    await repo.restorePack(backup);
    final listRestored = await repo.listPacks();
    expect(listRestored.any((p) => p.id == '1'), isTrue);
  });
}
