import 'package:image_picker/image_picker.dart';

/// Servicio para capturar fotos desde la cámara del dispositivo.
/// Usa image_picker, que abre la cámara nativa y devuelve la foto.
class CameraService {
  final ImagePicker _picker = ImagePicker();

  /// Abre la cámara y devuelve la foto tomada (o null si se canceló).
  /// La foto se comprime automáticamente para ahorrar almacenamiento.
  Future<XFile?> takePhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      // Compresión: 70% de calidad. Reduce mucho el peso
      // sin pérdida visual notable para evidencias.
      imageQuality: 70,
      // Limita el tamaño máximo (redimensiona si es más grande).
      maxWidth: 1600,
      maxHeight: 1600,
    );
    return photo;
  }
}