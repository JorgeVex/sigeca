import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/assignment_model.dart';
import '../../data/repositories/assignment_repository.dart';

/// Provee el repositorio de asignaciones.
final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) {
  return AssignmentRepository(Supabase.instance.client);
});

/// Representa un periodo (mes y año) seleccionado.
class Period {
  final int year;
  final int month;
  const Period(this.year, this.month);
}

/// Notifier que mantiene el periodo seleccionado y permite cambiarlo.
class SelectedPeriodNotifier extends Notifier<Period> {
  @override
  Period build() {
    final now = DateTime.now();
    return Period(now.year, now.month);
  }

  /// Cambia el periodo mostrado.
  void setPeriod(int year, int month) {
    state = Period(year, month);
  }
}

/// Periodo actualmente seleccionado para ver asignaciones.
final selectedPeriodProvider =
    NotifierProvider<SelectedPeriodNotifier, Period>(
        SelectedPeriodNotifier.new);

/// Lista de asignaciones del periodo seleccionado.
/// Se recarga automáticamente cuando cambia el periodo.
final assignmentsListProvider =
    FutureProvider<List<AssignmentModel>>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  final repository = ref.watch(assignmentRepositoryProvider);
  return repository.fetchByPeriod(year: period.year, month: period.month);
});

/// Lista de auxiliares activos (para el dropdown del formulario).
final auxiliaresListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(assignmentRepositoryProvider);
  return repository.fetchAuxiliares();
});

/// IDs de áreas ya asignadas en el periodo seleccionado.
final assignedAreaIdsProvider = FutureProvider<Set<String>>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  final repository = ref.watch(assignmentRepositoryProvider);
  return repository.fetchAssignedAreaIds(
      year: period.year, month: period.month);
});

/// IDs de ambulancias ya asignadas en el periodo seleccionado.
final assignedAmbulanceIdsProvider =
    FutureProvider<Set<String>>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  final repository = ref.watch(assignmentRepositoryProvider);
  return repository.fetchAssignedAmbulanceIds(
      year: period.year, month: period.month);
});