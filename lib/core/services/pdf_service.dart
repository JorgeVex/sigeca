import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Datos de un área con sus fotos, para el PDF.
class PdfAreaData {
  final String areaName;
  final List<Uint8List> photos; // bytes de cada foto

  PdfAreaData({required this.areaName, required this.photos});
}

/// Servicio que genera el PDF de un reporte semanal.
class PdfService {
  /// Genera el PDF y devuelve sus bytes.
  Future<Uint8List> generateWeeklyReport({
    required String auxiliarName,
    required String jefeName,
    required int weekNumber,
    required DateTime generatedAt,
    required List<PdfAreaData> areas,
  }) async {
    final doc = pw.Document();

    final ordinals = ['primer', 'segundo', 'tercer', 'cuarto'];
    final ordinal =
        weekNumber >= 1 && weekNumber <= 4 ? ordinals[weekNumber - 1] : '';

    final fecha = _formatDate(generatedAt);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 500, // sube el límite (por defecto son 20)
        build: (context) {
          return [
            // --- Encabezado ---
            pw.Header(
              level: 0,
              child: pw.Text('Reporte Semanal de Aseo — Semana $weekNumber',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 16),

            // --- Texto formal ---
            pw.Paragraph(
              text:
                  'Yo, $auxiliarName, en calidad de Auxiliar de Enfermería, '
                  'identificado(a) con CC ________, revisé y acepté la asignación '
                  'de áreas e insumos por parte de $jefeName, identificada con '
                  'CC ________. Siendo las ${_formatTime(generatedAt)} del $fecha, '
                  'adjunto la entrega del $ordinal reporte semanal de aseos en las '
                  'áreas que me corresponden, junto con las responsabilidades e '
                  'insumos (cuando aplique).',
            ),
            pw.SizedBox(height: 24),

            // --- Fotos por área ---
            ...areas.expand((area) => _buildAreaSection(area)),
          ];
        },
      ),
    );

    return doc.save();
  }

  /// Sección de un área: título + sus fotos en grilla de 4 por página (2x2).
  /// Devuelve una lista de widgets para que MultiPage pueda partir
  /// las fotos entre páginas automáticamente.
  List<pw.Widget> _buildAreaSection(PdfAreaData area) {
    final widgets = <pw.Widget>[];

    // Título del área.
    widgets.add(pw.SizedBox(height: 12));
    widgets.add(
      pw.Text(area.areaName,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
    );
    widgets.add(pw.Divider());
    widgets.add(pw.SizedBox(height: 8));

    if (area.photos.isEmpty) {
      widgets.add(pw.Text('Sin fotos registradas.',
          style: pw.TextStyle(
              fontSize: 10, color: PdfColors.grey600,
              fontStyle: pw.FontStyle.italic)));
      widgets.add(pw.SizedBox(height: 8));
      return widgets;
    }

    // Agrupar las fotos de 2 en 2 (filas), para una grilla 2x2 = 4 por página.
    for (int i = 0; i < area.photos.length; i += 2) {
      final rowPhotos = area.photos.skip(i).take(2).toList();
      widgets.add(_buildPhotoRow(rowPhotos));
      widgets.add(pw.SizedBox(height: 8));
    }

    widgets.add(pw.SizedBox(height: 12));
    return widgets;
  }

  /// Una fila con 1 o 2 fotos grandes, lado a lado.
  pw.Widget _buildPhotoRow(List<Uint8List> photos) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: photos.map((bytes) {
        return pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.all(4),
            height: 240, // foto grande: 2 por fila, 2 filas por página
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  String _formatTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }
}