import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/report_model.dart';
import '../providers/assignment_providers.dart';
import '../providers/report_providers.dart';
import 'report_areas_page.dart';

/// Pantalla puente de "Registrar evidencia":
/// toma la asignación del auxiliar, calcula la semana activa
/// (la primera no completada) y lleva directo a sus áreas.
class RegisterEvidencePage extends ConsumerWidget {
  const RegisterEvidencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myAssignmentAsync = ref.watch(myAssignmentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar evidencia'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: myAssignmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar:\n$err', textAlign: TextAlign.center),
          ),
        ),
        data: (assignment) {
          if (assignment == null) {
            return const _InfoMessage(
              icon: Icons.inbox,
              text: 'No tienes una carpeta asignada este mes.',
            );
          }

          if (!assignment.accepted) {
            return const _InfoMessage(
              icon: Icons.pending_actions,
              text: 'Primero debes aceptar tu asignación en "Mis asignaciones" '
                  'para poder registrar evidencia.',
            );
          }

          // Cargar las semanas para saber cuál es la activa.
          final reportsAsync =
              ref.watch(reportsListProvider(assignment.id));

          return reportsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (reports) {
              // Calcular la primera semana NO completada (1..4).
              int? activeWeek;
              for (int w = 1; w <= 4; w++) {
                final r = _reportForWeek(reports, w);
                final completed = r?.isCompleted ?? false;
                if (!completed) {
                  activeWeek = w;
                  break;
                }
              }

              // Si todas están completadas, no hay a dónde ir.
              if (activeWeek == null) {
                return const _InfoMessage(
                  icon: Icons.check_circle,
                  text: 'Ya completaste todas las semanas de este periodo. '
                      '¡Buen trabajo!',
                );
              }

              // Abrir la semana activa automáticamente (una sola vez).
              return _AutoOpenWeek(
                assignment: assignment,
                weekNumber: activeWeek,
                existingReport: _reportForWeek(reports, activeWeek),
              );
            },
          );
        },
      ),
    );
  }

  ReportModel? _reportForWeek(List<ReportModel> reports, int week) {
    for (final r in reports) {
      if (r.weekNumber == week) return r;
    }
    return null;
  }
}

/// Abre automáticamente la semana activa en ReportAreasPage.
/// Es un StatefulWidget para disparar la navegación una sola vez
/// después del primer frame.
class _AutoOpenWeek extends ConsumerStatefulWidget {
  final dynamic assignment; // AssignmentModel
  final int weekNumber;
  final ReportModel? existingReport;

  const _AutoOpenWeek({
    required this.assignment,
    required this.weekNumber,
    required this.existingReport,
  });

  @override
  ConsumerState<_AutoOpenWeek> createState() => _AutoOpenWeekState();
}

class _AutoOpenWeekState extends ConsumerState<_AutoOpenWeek> {
  bool _navigated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (_navigated) return;
    _navigated = true;

    ReportModel report;
    if (widget.existingReport == null) {
      final repo = ref.read(reportRepositoryProvider);
      try {
        report = await repo.createWeekReport(
          assignmentId: widget.assignment.id,
          weekNumber: widget.weekNumber,
          areaIds:
              widget.assignment.areas.map((a) => a.areaId).toList().cast<String>(),
          ambulanceIds: widget.assignment.ambulances
          .map((a) => a.ambulanceId).toList().cast<String>(), 
        );
        ref.invalidate(reportsListProvider(widget.assignment.id));
      } catch (e) {
        setState(() => _error = 'Error: $e');
        return;
      }
    } else {
      report = widget.existingReport!;
    }

    if (!mounted) return;

    // Reemplaza esta pantalla puente por las áreas de la semana activa.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReportAreasPage(
          report: report,
          assignment: widget.assignment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    // Mientras abre la semana, un spinner con mensaje.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Abriendo semana ${widget.weekNumber}...',
              style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

/// Mensaje informativo centrado (sin asignación, todo completo, etc).
class _InfoMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}