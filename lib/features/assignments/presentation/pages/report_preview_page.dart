import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../data/models/report_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/report_providers.dart';

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

  /// Arma el PDF: descarga las fotos y genera el documento.
  Future<Uint8List> _buildPdf(WidgetRef ref) async {
    final repo = ref.read(reportRepositoryProvider);
    final pdfService = ref.read(pdfServiceProvider);
    final profile = ref.read(currentProfileProvider).value;

    final areasData = await repo.buildPdfData(report.id);

    return pdfService.generateWeeklyReport(
      auxiliarName: profile?.fullName ?? 'Auxiliar',
      jefeName: 'Jefe de Enfermería',
      weekNumber: report.weekNumber,
      generatedAt: DateTime.now(),
      areas: areasData,
    );
  }
}