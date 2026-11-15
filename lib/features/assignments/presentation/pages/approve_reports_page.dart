import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/report_providers.dart';
import 'report_preview_page.dart';

const _months = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
];

/// Pantalla de la jefe: lista los reportes pendientes de aprobación
/// y permite aprobarlos o rechazarlos con un motivo.
class ApproveReportsPage extends ConsumerWidget {
  const ApproveReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingApprovalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aprobar reportes'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar:\n$err', textAlign: TextAlign.center),
          ),
        ),
        data: (pending) {
          if (pending.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No hay reportes pendientes de aprobación.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            itemCount: pending.length,
            itemBuilder: (context, index) {
              final p = pending[index];
              final mes = (p.periodMonth >= 1 && p.periodMonth <= 12)
                  ? _months[p.periodMonth - 1]
                  : '';
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(Icons.pending_actions,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.auxiliarName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                Text(
                                    'Semana ${p.report.weekNumber} — $mes ${p.periodYear}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Botón ver PDF.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf,
                              color: Colors.teal),
                          label: const Text('Ver reporte',
                              style: TextStyle(color: Colors.teal)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReportPreviewPage(report: p.report),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Botones aprobar / rechazar.
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.check),
                              label: const Text('Aprobar'),
                              onPressed: () =>
                                  _approve(context, ref, p.report.id),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.close),
                              label: const Text('Rechazar'),
                              onPressed: () =>
                                  _reject(context, ref, p.report.id),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _approve(
      BuildContext context, WidgetRef ref, String reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprobar reporte'),
        content: const Text(
            '¿Confirmas la aprobación de este reporte? Tu firma quedará '
            'registrada en el documento.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Aprobar', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final repo = ref.read(reportRepositoryProvider);
      final jefeId = Supabase.instance.client.auth.currentUser!.id;
      await repo.approveReport(reportId: reportId, jefeId: jefeId);
      ref.invalidate(pendingApprovalProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte aprobado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _reject(
      BuildContext context, WidgetRef ref, String reportId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar reporte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Indica el motivo del rechazo. El auxiliar lo verá para '
                'corregir el reporte.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ej: Faltan fotos del área X / fotos poco claras...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Escribe un motivo.')),
                );
                return;
              }
              Navigator.pop(context, text);
            },
            child: const Text('Rechazar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (reason == null) return;

    try {
      final repo = ref.read(reportRepositoryProvider);
      await repo.rejectReport(reportId: reportId, reason: reason);
      ref.invalidate(pendingApprovalProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte rechazado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}