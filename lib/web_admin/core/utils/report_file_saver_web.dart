import 'dart:async';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

Future<bool> saveReportFile(Uint8List bytes, String filename) async {
  final url = html.Url.createObjectUrlFromBlob(
    html.Blob(
      [bytes],
      filename.endsWith('.csv')
          ? 'text/csv;charset=utf-8'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ),
  );
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(seconds: 1), () => html.Url.revokeObjectUrl(url));
  return true;
}
