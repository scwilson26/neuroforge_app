import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

Future<void> addFilesToMultipart(http.MultipartRequest req, List<PlatformFile> files) async {
  for (final f in files) {
    if (f.path != null) {
      req.files.add(await http.MultipartFile.fromPath('files', f.path!, filename: f.name));
    } else if (f.bytes != null) {
      req.files.add(http.MultipartFile.fromBytes('files', f.bytes!, filename: f.name));
    }
  }
}
