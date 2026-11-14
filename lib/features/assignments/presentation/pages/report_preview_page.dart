import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../data/models/report_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/report_providers.dart';

import 'package:flutter/services.dart' show rootBundle;
/// Pantalla de previsualización del PDF del reporte.
/// Muestra el documento renderizado y permite compartirlo.
class ReportPreviewPage extends ConsumerWidget {
  final ReportModel report;

  const ReportPreviewPage({super.key, required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista previa del reporte'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        // Genera el PDF (bytes) cuando la pantalla se construye.
        build: (format) => _buildPdf(ref),
        // Nombre sugerido al compartir/guardar.
        pdfFileName: 'reporte_semana_${report.weekNumber}.pdf',
        // Ajustes de la barra de acciones.
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        // Deja visible el botón de compartir (viene por defecto).
        allowSharing: true,
        allowPrinting: true,
      ),
    );
  }

  /// Arma el PDF: descarga las fotos, la firma, y genera el documento.
  Future<Uint8List> _buildPdf(WidgetRef ref) async {
    final repo = ref.read(reportRepositoryProvider);
    final storage = ref.read(storageServiceProvider);
    final pdfService = ref.read(pdfServiceProvider);
    final profile = ref.read(currentProfileProvider).value;

    final areasData = await repo.buildPdfData(report.id);

    // Descargar la firma del auxiliar desde Storage (si existe).
    Uint8List? signatureBytes;
    final signaturePath = profile?.signatureUrl;
    if (signaturePath != null && signaturePath.isNotEmpty) {
      try {
        signatureBytes = await storage.downloadPhoto(signaturePath);
      } catch (_) {
        signatureBytes = null; // si falla, el PDF sale sin imagen de firma
      }
    }

    Uint8List logoBytes;
    try {
      final data = await rootBundle.load('assets/images/logoese.png');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {
      logoBytes = Uint8List(0); // si falla, el PDF sale sin logo
    }

    return pdfService.generateWeeklyReport(
      auxiliarName: profile?.fullName ?? 'Auxiliar',
      auxiliarDocument: profile?.documentId ?? '',
      jefeName: 'Jefe de Enfermería',
      weekNumber: report.weekNumber,
      generatedAt: DateTime.now(),
      areas: areasData,
      auxiliarSignature: signatureBytes,
      logo: logoBytes,
    );
  }
}