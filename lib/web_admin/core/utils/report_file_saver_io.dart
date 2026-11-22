import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<bool> saveReportFile(Uint8List bytes, String filename) async {
  final extension = filename.split('.').last;
  final mobile = Platform.isAndroid || Platform.isIOS;
  var path = await FilePicker.platform.saveFile(
    dialogTitle: 'Simpan laporan',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: [extension],
    bytes: mobile ? bytes : null,
  );
  if (path == null) return false;
  if (!mobile) {
    if (!path.toLowerCase().endsWith('.$extension')) path = '$path.$extension';
    await File(path).writeAsBytes(bytes, flush: true);
  }
  return true;
}
