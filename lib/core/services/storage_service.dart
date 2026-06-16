import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para subir archivos a Supabase Storage.
class StorageService {
  final SupabaseClient _client;

  StorageService(this._client);

  static const String _bucket = 'evidences';

  /// Sube una foto al bucket y devuelve la ruta del archivo.
  /// La ruta se organiza por reporte y área para mantener orden.
  Future<String> uploadPhoto({
    required XFile photo,
    required String reportId,
    required String areaId,
  }) async {
    // Nombre único para el archivo, usando la marca de tiempo.
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$timestamp.jpg';

    // Ruta organizada: reportes/<reportId>/<areaId>/<archivo>.
    final path = 'reports/$reportId/$areaId/$fileName';

    // Lee los bytes de la foto y la sube.
    final bytes = await File(photo.path).readAsBytes();

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );

    return path;
  }

  /// Genera una URL firmada temporal para ver una foto privada.
  /// El bucket es privado, así que se necesita esta URL para mostrarla.
  Future<String> getSignedUrl(String path) async {
    final signedUrl = await _client.storage
        .from(_bucket)
        .createSignedUrl(path, 3600); // válida 1 hora
    return signedUrl;
  }

  /// Elimina una foto del Storage por su ruta.
  Future<void> deletePhoto(String path) async {
    await _client.storage.from(_bucket).remove([path]);
  }
}