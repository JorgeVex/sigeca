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

    // Ordinal de la semana en palabras.
    final ordinals = ['primer', 'segundo', 'tercer', 'cuarto'];
    final ordinal =
        weekNumber >= 1 && weekNumber <= 4 ? ordinals[weekNumber - 1] : '';

    final fecha = _formatDate(generatedAt);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
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

            // --- Plantilla / texto formal ---
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
            ...areas.map((area) => _buildAreaSection(area)),
          ];
        },
      ),
    );

    return doc.save();
  }

  /// Sección de un área con su grilla de fotos.
  pw.Widget _buildAreaSection(PdfAreaData area) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 12),
        pw.Text(area.areaName,
            style:
                pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Divider(),
        pw.SizedBox(height: 8),
        // Grilla de fotos: filas de 3.
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: area.photos.map((bytes) {
            return pw.Container(
              width: 150,
              height: 150,
              child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
            );
          }).toList(),
        ),
        pw.SizedBox(height: 16),
      ],
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