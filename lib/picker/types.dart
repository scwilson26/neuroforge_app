import 'dart:typed_data';

class PickedFile {
  final String name;
  final int size; // bytes
  final Uint8List? bytes; // present on web or when withData=true
  final String? path; // present on IO platforms when available
  const PickedFile({required this.name, required this.size, this.bytes, this.path});
}

class FileRejection {
  final String name;
  final int size;
  final String reason;
  const FileRejection({required this.name, required this.size, required this.reason});
}

class PickerResult {
  final List<PickedFile> accepted;
  final List<FileRejection> rejected;
  const PickerResult({required this.accepted, required this.rejected});
}

// Shared validation: enforce per-file max size in bytes.
PickerResult filterByMaxSize(List<PickedFile> files, int maxSizeBytes) {
  final accepted = <PickedFile>[];
  final rejected = <FileRejection>[];
  for (final f in files) {
    if (f.size > maxSizeBytes) {
      rejected.add(FileRejection(
        name: f.name,
        size: f.size,
        reason: 'File exceeds limit of ${(maxSizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB',
      ));
    } else {
      accepted.add(f);
    }
  }
  return PickerResult(accepted: accepted, rejected: rejected);
}
