import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'dart:math';

/// Servicio para subir archivos a Supabase Storage.
class StorageService {
  final SupabaseClient _client;

  StorageService(this._client);

  static const String _bucket = 'evidences';

    /// Genera un nombre único: timestamp + aleatorio, para evitar
  /// colisiones cuando se suben varias fotos en el mismo instante.
  String _uniqueName() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(1000000);
    return '${ts}_$rand.jpg';
  }

  /// Sube una foto al bucket y devuelve la ruta del archivo.
  /// La ruta se organiza por reporte y área para mantener orden.
  Future<String> uploadPhoto({
    required XFile photo,
    required String reportId,
    required String areaId,
  }) async {
    // Nombre único para el archivo, usando la marca de tiempo.
    final fileName = _uniqueName();


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
/// Sube una foto de insumo al bucket, organizada por insumo.
  Future<String> uploadSupplyPhoto({
    required XFile photo,
    required String assignmentSupplyId,
  }) async {
    final path = _uniqueName();

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
  Future <Uint8List> downloadPhoto(String path) async {
    final bytes = await _client.storage.from(_bucket).download(path);
    return bytes;
  }
  /// Sube la firma de un usuario al bucket, en su propia carpeta.
  /// Devuelve la ruta del archivo guardado.
  Future<String> uploadSignature({
    required XFile photo,
    required String userId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'signatures/$userId/$timestamp.jpg';

    final bytes = await File(photo.path).readAsBytes();

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return path;
  }


}