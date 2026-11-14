import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/assignment_providers.dart';
import '../providers/report_providers.dart';
import '../../data/models/assignment_model.dart';
import '../../data/models/report_model.dart';
import 'report_preview_page.dart';

const _months = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
];

/// "Mis reportes": carpetas por mes. Cada carpeta abre las
/// semanas completadas de ese mes, con su PDF.
class MyReportsPage extends ConsumerWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(myAssignmentsHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reportes'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar:\n$err', textAlign: TextAlign.center),
          ),
        ),
        data: (assignments) {
          if (assignments.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no tienes carpetas asignadas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
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
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final a = assignments[index];
              final monthName = (a.periodMonth >= 1 && a.periodMonth <= 12)
                  ? _months[a.periodMonth - 1]
                  : 'Mes ${a.periodMonth}';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.folder, color: Colors.white),
                  ),
                  title: Text('$monthName ${a.periodYear}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Ver reportes del mes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _MonthReportsPage(
                          assignment: a,
                          monthName: monthName,
                        ),
                      ),
                    );
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

/// Semanas completadas de un mes (una carpeta/asignación).
class _MonthReportsPage extends ConsumerWidget {
  final AssignmentModel assignment;
  final String monthName;

  const _MonthReportsPage({
    required this.assignment,
    required this.monthName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsListProvider(assignment.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('$monthName ${assignment.periodYear}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (reports) {
          final completed = reports.where((r) => r.isCompleted).toList()
            ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

          if (completed.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_outlined,
                        size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Este mes no tiene reportes completados todavía.',
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
            itemCount: completed.length,
            itemBuilder: (context, index) {
              final report = completed[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.description, color: Colors.white),
                  ),
                  title: Text('Semana ${report.weekNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_subtitleFor(report)),
                  trailing:
                      const Icon(Icons.picture_as_pdf, color: Colors.red),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportPreviewPage(report: report),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _subtitleFor(ReportModel report) {
    final date = report.completedAt;
    if (date == null) return 'Completado';
    return 'Entregado el ${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}