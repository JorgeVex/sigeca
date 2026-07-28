import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Servicio que estampa un sello (nombre, fecha/hora, área)
/// en la esquina inferior izquierda de una foto.
class WatermarkService {
  /// Recibe una foto y le graba el sello. Devuelve la ruta del
  /// archivo nuevo (con marca de agua), listo para subir.
  Future<XFile> applyWatermark({
    required XFile photo,
    required String auxiliarName,
    required String label, // nombre del área o insumo
    DateTime? capturedAt,
  }) async {
    final when = capturedAt ?? DateTime.now();

    // 1. Leer la imagen original.
    final bytes = await File(photo.path).readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) {
      // Si no se pudo decodificar, devolver la original sin sello.
      return photo;
    }

    // 2. Preparar las tres líneas del sello.
    final fecha = _formatDate(when);
    final lines = [
      auxiliarName,
      fecha,
      label,
    ];

    // 3. Dibujar cada línea en la esquina inferior izquierda.
    //    Usamos una fuente incorporada del paquete.
    final font = img.arial48; // tamaño 48, blanco con borde negro
    const margin = 24;
    const lineHeight = 56;

    // Calcular la posición vertical de la primera línea.
    // Las líneas se apilan hacia arriba desde el fondo.
    final totalHeight = lines.length * lineHeight;
    int y = original.height - totalHeight - margin;

    for (final line in lines) {
      // Borde negro (dibujando el texto desplazado en 4 direcciones).
      for (final dx in [-3, 3]) {
        for (final dy in [-3, 3]) {
          img.drawString(
            original,
            line,
            font: font,
            x: margin + dx,
            y: y + dy,
            color: img.ColorRgb8(0, 0, 0),
          );
        }
      }
      // Texto blanco encima.
      img.drawString(
        original,
        line,
        font: font,
        x: margin,
        y: y,
        color: img.ColorRgb8(255, 255, 255),
      );
      y += lineHeight;
    }

    // 4. Guardar la imagen sellada en un archivo temporal.
    final jpg = img.encodeJpg(original, quality: 85);
    final tempDir = await getTemporaryDirectory();
    final newPath =
        '${tempDir.path}/wm_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final newFile = File(newPath);
    await newFile.writeAsBytes(jpg);

    return XFile(newPath);
  }

  /// Formato colombiano: DD/MM/AAAA HH:MM
  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}