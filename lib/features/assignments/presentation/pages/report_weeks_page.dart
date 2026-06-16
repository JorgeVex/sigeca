import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/assignment_model.dart';
import '../../data/models/report_model.dart';
import '../providers/report_providers.dart';
import 'report_areas_page.dart';

/// Pantalla de las 4 semanas de reportes de un auxiliar.
/// Aplica la lógica secuencial: una semana se desbloquea
/// cuando la anterior está completada.
class ReportWeeksPage extends ConsumerWidget {
  final AssignmentModel assignment;
  const ReportWeeksPage({super.key, required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsListProvider(assignment.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes semanales'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar:\n$err',
                textAlign: TextAlign.center),
          ),
        ),
        data: (reports) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Completa cada semana en orden. Una semana se habilita '
                'cuando cierras la anterior.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              // Genera las 4 semanas.
              ...List.generate(4, (i) {
                final weekNumber = i + 1;
                return _buildWeekCard(context, ref, weekNumber, reports);
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWeekCard(
    BuildContext context,
    WidgetRef ref,
    int weekNumber,
    List<ReportModel> reports,
  ) {
    // Buscar si esta semana ya tiene reporte.
    ReportModel? report;
    for (final r in reports) {
      if (r.weekNumber == weekNumber) {
        report = r;
        break;
      }
    }

    // Determinar si la semana anterior está completada.
    bool previousCompleted = weekNumber == 1; // la 1 no tiene anterior
    if (weekNumber > 1) {
      for (final r in reports) {
        if (r.weekNumber == weekNumber - 1 && r.isCompleted) {
          previousCompleted = true;
          break;
        }
      }
    }

    // Estado de la semana.
    final isCompleted = report?.isCompleted ?? false;
    final isInProgress = report != null && !report.isCompleted;
    final isLocked = !isCompleted && !isInProgress && !previousCompleted;

    // Estilo según estado.
    IconData icon;
    Color color;
    String subtitle;
    if (isCompleted) {
      icon = Icons.check_circle;
      color = Colors.green;
      subtitle = 'Completada';
    } else if (isInProgress) {
      icon = Icons.pending;
      color = Colors.orange;
      subtitle = 'En progreso';
    } else if (isLocked) {
      icon = Icons.lock;
      color = Colors.grey;
      subtitle = 'Bloqueada — completa la semana anterior';
    } else {
      icon = Icons.play_circle_outline;
      color = Colors.teal;
      subtitle = 'Disponible';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text('Semana $weekNumber',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: isLocked ? null : const Icon(Icons.chevron_right),
        enabled: !isLocked,
        onTap: isLocked
            ? null
            : () => _openWeek(context, ref, weekNumber, report),
      ),
    );
  }

  Future<void> _openWeek(
    BuildContext context,
    WidgetRef ref,
    int weekNumber,
    ReportModel? existingReport,
  ) async {
    ReportModel report;

    // Si la semana aún no tiene reporte, crearlo ahora.
    if (existingReport == null) {
      final repo = ref.read(reportRepositoryProvider);
      try {
        report = await repo.createWeekReport(
          assignmentId: assignment.id,
          weekNumber: weekNumber,
          areaIds: assignment.areas.map((a) => a.areaId).toList(),
        );
        ref.invalidate(reportsListProvider(assignment.id));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
        return;
      }
    } else {
      report = existingReport;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportAreasPage(
            report: report,
            assignment: assignment,
          ),
        ),
      );
    }
  }
}