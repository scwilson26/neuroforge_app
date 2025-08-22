import 'package:file_picker/file_picker.dart' as fp;
import 'types.dart';
import 'picker_stub.dart';

class WebNotesPicker implements NotesPicker {
  @override
  Future<List<PickedFile>?> pickMultiple({List<String>? allowedExtensions}) async {
    final res = await fp.FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: fp.FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (res == null) return null;
    return res.files.map((f) => PickedFile(name: f.name, size: f.size, bytes: f.bytes, path: null)).toList();
  }
}

NotesPicker getNotesPicker() => WebNotesPicker();
