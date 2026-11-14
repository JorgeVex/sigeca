import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Datos de un área con sus fotos, para el PDF.
class PdfAreaData {
  final String areaName;
  final List<Uint8List> photos;

  PdfAreaData({required this.areaName, required this.photos});
}

/// Servicio que genera el PDF de un reporte semanal (diseño institucional).
class PdfService {
  // --- Paleta institucional ---
  static final PdfColor verdePrincipal = PdfColor.fromInt(0xFF16845B);
  static final PdfColor verdeOscuro = PdfColor.fromInt(0xFF105C43);
  static final PdfColor verdeSuave = PdfColor.fromInt(0xFFEAF5EF);
  static final PdfColor celeste = PdfColor.fromInt(0xFF55B8DF);
  static final PdfColor celesteSuave = PdfColor.fromInt(0xFFE8F5FB);
  static final PdfColor grisFondo = PdfColor.fromInt(0xFFF4F6F7);
  static final PdfColor grisTexto = PdfColor.fromInt(0xFF667085);
  static final PdfColor grisOscuro = PdfColor.fromInt(0xFF263238);

  Future<Uint8List> generateWeeklyReport({
    required String auxiliarName,
    required String auxiliarDocument,
    required String jefeName,
    required int weekNumber,
    required DateTime generatedAt,
    required List<PdfAreaData> areas,
    Uint8List? auxiliarSignature,
    Uint8List? logo,
  }) async {
    final doc = pw.Document();

    final fecha = _formatDate(generatedAt);
    final hora = _formatTime(generatedAt);
    final cedula = auxiliarDocument.isEmpty ? '________' : auxiliarDocument;

    final logoImage = logo != null ? pw.MemoryImage(logo) : null;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 34, vertical: 28),
        maxPages: 500,
        // Pie de página uniforme en todas las páginas.
        footer: (context) => _buildFooter(context, weekNumber),
        build: (context) {
          return [
            // --- Encabezado institucional ---
            _buildHeader(
              logoImage: logoImage,
              weekNumber: weekNumber,
              fecha: fecha,
              hora: hora,
              auxiliarName: auxiliarName,
              cedula: cedula,
            ),
            pw.SizedBox(height: 18),

            // --- Fotos por área ---
            ...areas.expand((area) => _buildAreaSection(area)),

            // --- Declaración + firmas ---
            _buildSignatureSection(
              auxiliarName: auxiliarName,
              cedula: cedula,
              jefeName: jefeName,
              auxiliarSignature: auxiliarSignature,
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  // ======================= ENCABEZADO =======================
  pw.Widget _buildHeader({
    pw.MemoryImage? logoImage,
    required int weekNumber,
    required String fecha,
    required String hora,
    required String auxiliarName,
    required String cedula,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Franja superior: logo + título.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoImage != null)
              pw.Container(
                width: 64,
                height: 64,
                margin: const pw.EdgeInsets.only(right: 14),
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('E.S.E. Hospital Laura Perdomo de García',
                      style: pw.TextStyle(
                          fontSize: 11,
                          color: grisTexto,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('Reporte Semanal de Aseo',
                      style: pw.TextStyle(
                          fontSize: 22,
                          color: verdePrincipal,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            // Badge de la semana en celeste.
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(
                color: celeste,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('SEMANA',
                      style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text('$weekNumber',
                      style: pw.TextStyle(
                          fontSize: 20,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        // Línea de acento verde+celeste.
        pw.Row(
          children: [
            pw.Expanded(
                flex: 3,
                child: pw.Container(height: 3, color: verdePrincipal)),
            pw.Expanded(
                flex: 1, child: pw.Container(height: 3, color: celeste)),
          ],
        ),
        pw.SizedBox(height: 14),

        // Bloque de datos del responsable (fondo verde suave).
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: verdeSuave,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoCell('RESPONSABLE', auxiliarName),
              _infoCell('DOCUMENTO', 'C.C. $cedula'),
              _infoCell('FECHA', fecha),
              _infoCell('HORA', hora),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _infoCell(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 8,
                  color: grisTexto,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10,
                  color: grisOscuro,
                  fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // ======================= PIE DE PÁGINA =======================
  pw.Widget _buildFooter(pw.Context context, int weekNumber) {
    return pw.Column(
      children: [
        pw.Container(height: 1.5, color: verdeSuave),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Reporte de Aseo | Semana $weekNumber',
                style: pw.TextStyle(fontSize: 8, color: grisTexto)),
            pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: grisTexto)),
          ],
        ),
      ],
    );
  }

  // ======================= ÁREAS =======================
  List<pw.Widget> _buildAreaSection(PdfAreaData area) {
    final widgets = <pw.Widget>[];

    // Título de área: acento celeste + nombre verde oscuro.
    widgets.add(pw.SizedBox(height: 14));
    widgets.add(
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 6,
            height: 18,
            decoration: pw.BoxDecoration(
              color: celeste,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(area.areaName,
              style: pw.TextStyle(
                  fontSize: 14,
                  color: verdeOscuro,
                  fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
    widgets.add(pw.SizedBox(height: 4));
    widgets.add(pw.Container(height: 1, color: grisFondo));
    widgets.add(pw.SizedBox(height: 8));

    if (area.photos.isEmpty) {
      widgets.add(pw.Text('Sin fotos registradas.',
          style: pw.TextStyle(
              fontSize: 10,
              color: grisTexto,
              fontStyle: pw.FontStyle.italic)));
      return widgets;
    }

    // Distribución: filas de hasta 3 (para 3,5,6) o de 2 (para 2,4).
    // 5 fotos -> 3 + 2 centradas. Cada foto mantiene celda de alto fijo.
    final perRow = _photosPerRow(area.photos.length);

    for (int i = 0; i < area.photos.length; i += perRow) {
      final rowPhotos = area.photos.skip(i).take(perRow).toList();
      widgets.add(_buildPhotoRow(rowPhotos, perRow));
      widgets.add(pw.SizedBox(height: 6));
    }

    widgets.add(pw.SizedBox(height: 10));
    return widgets;
  }

  /// Cuántas fotos por fila según el total (equilibrio visual).
  int _photosPerRow(int count) {
    if (count <= 2) return count; // 1 o 2 en una fila
    if (count == 4) return 2; // 2x2
    return 3; // 3, 5, 6, ... -> filas de 3
  }

  /// Una fila de fotos. `perRow` fija el ancho de celda, de modo que
  /// una fila incompleta (ej. 2 de 3) NO se estire al ancho total:
  /// se centran con celdas del mismo tamaño que las demás.
  pw.Widget _buildPhotoRow(List<Uint8List> photos, int perRow) {
    // Altura de celda según cuántas columnas (más columnas = más bajas).
    final cellHeight = perRow >= 3 ? 150.0 : 230.0;

    final cells = photos
        .map((bytes) => pw.Expanded(child: _photoCard(bytes, cellHeight)))
        .toList();

    // Rellenar con celdas vacías para centrar filas incompletas.
    final missing = perRow - photos.length;
    if (missing > 0) {
      // Media celda vacía a cada lado para centrar.
      return pw.Row(
        children: [
          pw.Spacer(flex: missing),
          ...cells.expand((c) => [c, pw.SizedBox(width: 0)]),
          pw.Spacer(flex: missing),
        ],
      );
    }

    // Fila completa: separación uniforme.
    final spaced = <pw.Widget>[];
    for (int i = 0; i < cells.length; i++) {
      spaced.add(cells[i]);
      if (i < cells.length - 1) spaced.add(pw.SizedBox(width: 6));
    }
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: spaced,
    );
  }

  /// Tarjeta individual de foto: borde sutil, esquinas redondeadas,
  /// fondo neutro, imagen centrada con proporción intacta.
  pw.Widget _photoCard(Uint8List bytes, double height) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(3),
      height: height,
      decoration: pw.BoxDecoration(
        color: grisFondo,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 6,
        verticalRadius: 6,
        child: pw.Center(
          child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
        ),
      ),
    );
  }

  // ======================= FIRMAS =======================
  pw.Widget _buildSignatureSection({
    required String auxiliarName,
    required String cedula,
    required String jefeName,
    Uint8List? auxiliarSignature,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 22),
        pw.Container(height: 1, color: grisFondo),
        pw.SizedBox(height: 12),
        pw.Text('DECLARACIÓN',
            style: pw.TextStyle(
                fontSize: 12,
                color: verdeOscuro,
                fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(
          'Declaro que las evidencias contenidas en este reporte son veraces '
          'y corresponden a las actividades de aseo realizadas por mí en las '
          'áreas asignadas.',
          style: pw.TextStyle(fontSize: 11, color: grisOscuro),
          textAlign: pw.TextAlign.justify,
        ),
        pw.SizedBox(height: 32),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _signatureBlock(
                signature: auxiliarSignature,
                name: auxiliarName,
                line2: 'C.C. $cedula',
                role: 'Auxiliar de Enfermería',
                pending: false,
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: _signatureBlock(
                signature: null,
                name: jefeName,
                line2: null,
                role: 'Jefe de Enfermería',
                pending: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _signatureBlock({
    Uint8List? signature,
    required String name,
    String? line2,
    required String role,
    required bool pending,
  }) {
    return pw.Column(
      children: [
        pw.Container(
          height: 56,
          alignment: pw.Alignment.center,
          child: pending
              ? pw.Text('Pendiente de aprobación',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                      color: grisTexto))
              : (signature != null
                  ? pw.Image(pw.MemoryImage(signature), fit: pw.BoxFit.contain)
                  : pw.SizedBox()),
        ),
        pw.Container(
          width: 180,
          decoration: pw.BoxDecoration(
            border: pw.Border(
                top: pw.BorderSide(color: grisOscuro, width: 1)),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(name,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center),
        if (line2 != null)
          pw.Text(line2,
              style: pw.TextStyle(fontSize: 9, color: grisOscuro),
              textAlign: pw.TextAlign.center),
        pw.Text(role,
            style: pw.TextStyle(fontSize: 9, color: grisTexto),
            textAlign: pw.TextAlign.center),
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