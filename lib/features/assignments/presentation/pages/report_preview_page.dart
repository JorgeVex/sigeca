import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../data/models/report_model.dart';
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
        build: (format) => _buildPdf(ref),
        pdfFileName: 'reporte_semana_${report.weekNumber}.pdf',
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowSharing: true,
        allowPrinting: true,
      ),
    );
  }

  /// Arma el PDF: descarga fotos, firmas, logo, y genera el documento.
  /// Recarga el reporte FRESCO de la BD para tener su estado actual
  /// (aprobado/rechazado), sin depender del objeto que llegó a la pantalla.
  Future<Uint8List> _buildPdf(WidgetRef ref) async {
    final repo = ref.read(reportRepositoryProvider);
    final storage = ref.read(storageServiceProvider);
    final pdfService = ref.read(pdfServiceProvider);

    // Reporte fresco (estado actual).
    ReportModel freshReport;
    try {
      freshReport = await repo.fetchReportById(report.id);
    } catch (_) {
      freshReport = report; // si falla, usa el que llegó
    }

    final areasData = await repo.buildPdfData(report.id);

    // --- Datos del auxiliar dueño del reporte ---
    String auxiliarName = 'Auxiliar';
    String auxiliarDocument = '';
    Uint8List? auxiliarSignature;

    try {
      final aux = await repo.fetchReportAuxiliar(report.id);
      if (aux != null) {
        auxiliarName = aux['full_name'] as String? ?? 'Auxiliar';
        auxiliarDocument = aux['document_id'] as String? ?? '';
        final sigPath = aux['signature_url'] as String?;
        if (sigPath != null && sigPath.isNotEmpty) {
          auxiliarSignature = await storage.downloadPhoto(sigPath);
        }
      }
    } catch (_) {
      // si falla, el PDF sale con valores por defecto
    }

    // --- Logo institucional ---
    Uint8List? logoBytes;
    try {
      final data = await rootBundle.load('assets/images/logoese.png');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {
      logoBytes = null;
    }

    // --- Datos de la jefe (solo si el reporte está aprobado) ---
    String jefeName = 'Jefe de Enfermería';
    String? jefeDocument;
    Uint8List? jefeSignatureBytes;

    if (freshReport.isApproved && freshReport.approvedBy != null) {
      try {
        final jefeData =
            await repo.fetchProfileSignature(freshReport.approvedBy!);
        if (jefeData != null) {
          jefeName = jefeData['full_name'] as String? ?? jefeName;
          jefeDocument = jefeData['document_id'] as String?;
          final jefeSigPath = jefeData['signature_url'] as String?;
          if (jefeSigPath != null && jefeSigPath.isNotEmpty) {
            jefeSignatureBytes = await storage.downloadPhoto(jefeSigPath);
          }
        }
      } catch (_) {
        // si falla, el PDF sale sin firma de jefe
      }
    }

    return pdfService.generateWeeklyReport(
      auxiliarName: auxiliarName,
      auxiliarDocument: auxiliarDocument,
      jefeName: jefeName,
      weekNumber: freshReport.weekNumber,
      generatedAt: DateTime.now(),
      areas: areasData,
      auxiliarSignature: auxiliarSignature,
      logo: logoBytes,
      jefeSignature: jefeSignatureBytes,
      jefeDocument: jefeDocument,
      isApproved: freshReport.isApproved,
      approvedAt: freshReport.approvedAt,
    );
  }
}