import 'types.dart';

abstract class NotesPicker {
  Future<List<PickedFile>?> pickMultiple({List<String>? allowedExtensions});
}

NotesPicker getNotesPicker() => throw UnsupportedError('Platform not supported');
