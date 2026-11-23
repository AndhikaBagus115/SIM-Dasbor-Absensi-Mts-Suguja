import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';

class SuratAttachmentService {
  static Future<String> signedUrl(String original) async {
    final uri = Uri.parse(original);
    final project = Uri.parse(AppConstants.supabaseUrl);
    const prefix = '/storage/v1/object/public/surat_keterangan/';
    if (uri.origin != project.origin || !uri.path.startsWith(prefix)) {
      throw StateError('Lokasi lampiran tidak valid.');
    }
    final path = Uri.decodeComponent(uri.path.substring(prefix.length));
    if (path.isEmpty ||
        path.split('/').any((p) => p == '..' || p == '.' || p.isEmpty)) {
      throw StateError('Path lampiran tidak valid.');
    }
    return Supabase.instance.client.storage
        .from('surat_keterangan')
        .createSignedUrl(path, 120);
  }
}
