import 'package:flutter_test/flutter_test.dart';
import 'package:neuroforge_app/picker/types.dart' as pick;

void main() {
  group('filterByMaxSize', () {
    test('accepts files <= limit', () {
      final files = [
        pick.PickedFile(name: 'a.pdf', size: 1024),
        pick.PickedFile(name: 'b.txt', size: 10 * 1024 * 1024),
      ];
      final res = pick.filterByMaxSize(files, 10 * 1024 * 1024);
      expect(res.accepted.length, 2);
      expect(res.rejected, isEmpty);
    });

    test('rejects files > limit', () {
      final files = [
        pick.PickedFile(name: 'a.pdf', size: 11 * 1024 * 1024),
        pick.PickedFile(name: 'b.txt', size: 9 * 1024 * 1024),
      ];
      final res = pick.filterByMaxSize(files, 10 * 1024 * 1024);
      expect(res.accepted.length, 1);
      expect(res.rejected.length, 1);
      expect(res.rejected.first.name, 'a.pdf');
    });
  });
}
