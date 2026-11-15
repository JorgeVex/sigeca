import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/report_model.dart';
import '../../data/repositories/report_repository.dart';
import '../providers/report_providers.dart';
import 'report_preview_page.dart';

const _months = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
];

/// NIVEL 1 — Lista de auxiliares del equipo, con semáforo de progreso.
class ApproveReportsPage extends ConsumerWidget {
  const ApproveReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auxAsync = ref.watch(teamAuxiliaresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes del equipo'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: auxAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar:\n$err', textAlign: TextAlign.center),
          ),
        ),
        data: (auxiliares) {
          if (auxiliares.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay auxiliares con asignación este mes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
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
            itemCount: auxiliares.length,
            itemBuilder: (context, index) {
              final aux = auxiliares[index];
              final info = _statusInfo(aux.status);
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: info.color,
                    child: Icon(info.icon, color: Colors.white),
                  ),
                  title: Text(aux.auxiliarName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${aux.closedCount} de ${TeamAuxiliar.expectedPerMonth} semanas · ${info.label}',
                    style: TextStyle(color: info.color),
                  ),
                  trailing: aux.pendingCount > 0
                      ? Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Text('${aux.pendingCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _AuxiliarFoldersPage(
                          auxiliarId: aux.auxiliarId,
                          auxiliarName: aux.auxiliarName,
                        ),
                      ),
                    ).then((_) => ref.invalidate(teamAuxiliaresProvider));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  _StatusInfo _statusInfo(TeamStatus status) {
    switch (status) {
      case TeamStatus.pending:
        return _StatusInfo(Colors.orange, Icons.pending_actions, 'Por revisar');
      case TeamStatus.inProgress:
        return _StatusInfo(Colors.blue, Icons.hourglass_bottom, 'En progreso');
      case TeamStatus.done:
        return _StatusInfo(Colors.green, Icons.check, 'Al día');
      case TeamStatus.notStarted:
        return _StatusInfo(Colors.grey, Icons.remove, 'Sin empezar');
    }
  }
}

/// NIVEL 2 — Carpetas (meses) de un auxiliar.
class _AuxiliarFoldersPage extends ConsumerWidget {
  final String auxiliarId;
  final String auxiliarName;

  const _AuxiliarFoldersPage({
    required this.auxiliarId,
    required this.auxiliarName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(auxiliarFoldersProvider(auxiliarId));

    return Scaffold(
      appBar: AppBar(
        title: Text(auxiliarName),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: foldersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (folders) {
          if (folders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Este auxiliar no tiene carpetas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
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
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final f = folders[index];
              final mes = (f.periodMonth >= 1 && f.periodMonth <= 12)
                  ? _months[f.periodMonth - 1]
                  : 'Mes ${f.periodMonth}';
              final hasPending = f.pendingCount > 0;
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: hasPending ? Colors.orange : Colors.teal,
                    child: const Icon(Icons.folder, color: Colors.white),
                  ),
                  title: Text('$mes ${f.periodYear}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(hasPending
                      ? '${f.pendingCount} por revisar'
                      : 'Ver reportes'),
                  trailing: hasPending
                      ? Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Text('${f.pendingCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _FolderReportsPage(
                          assignmentId: f.assignmentId,
                          title: '$auxiliarName — $mes ${f.periodYear}',
                        ),
                      ),
                    ).then((_) =>
                        ref.invalidate(auxiliarFoldersProvider(auxiliarId)));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// NIVEL 3 — Reportes de una carpeta (todos los estados).
class _FolderReportsPage extends ConsumerWidget {
  final String assignmentId;
  final String title;

  const _FolderReportsPage({
    required this.assignmentId,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsListProvider(assignmentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (reports) {
          final visible = reports
              .where((r) => r.isCompleted || r.isApproved || r.isRejected)
              .toList()
            ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

          if (visible.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay reportes cerrados en este mes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
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
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final report = visible[index];
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
                          CircleAvatar(
                            backgroundColor: _statusColor(report),
                            child: Icon(_statusIcon(report),
                                color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Semana ${report.weekNumber}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                Text(_statusLabel(report),
                                    style: TextStyle(
                                        color: _statusColor(report),
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                                    ReportPreviewPage(report: report),
                              ),
                            );
                          },
                        ),
                      ),
                      if (report.isPendingApproval) ...[
                        const SizedBox(height: 8),
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
                                    _approve(context, ref, report.id),
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
                                    _reject(context, ref, report.id),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Color _statusColor(ReportModel r) {
    if (r.isApproved) return Colors.green;
    if (r.isRejected) return Colors.red;
    return Colors.orange;
  }

  IconData _statusIcon(ReportModel r) {
    if (r.isApproved) return Icons.verified;
    if (r.isRejected) return Icons.cancel;
    return Icons.pending;
  }

  String _statusLabel(ReportModel r) {
    if (r.isApproved) {
      final d = r.approvedAt;
      return d != null
          ? 'Aprobado el ${d.day.toString().padLeft(2, '0')}/'
              '${d.month.toString().padLeft(2, '0')}/${d.year}'
          : 'Aprobado';
    }
    if (r.isRejected) return 'Rechazado: ${r.rejectionReason ?? 'sin motivo'}';
    return 'Pendiente de aprobación';
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
      ref.invalidate(reportsListProvider(assignmentId));
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
                hintText: 'Ej: Faltan fotos del área X...',
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
      ref.invalidate(reportsListProvider(assignmentId));
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

/// Datos visuales de un estado del semáforo.
class _StatusInfo {
  final Color color;
  final IconData icon;
  final String label;
  _StatusInfo(this.color, this.icon, this.label);
}