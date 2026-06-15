import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/assignment_model.dart';
import '../providers/assignment_providers.dart';
import 'assignments_form_page.dart';
import 'assignments_detail_page.dart';

/// Pantalla de gestión de asignaciones (jefe).
/// Muestra una carpeta por auxiliar en el periodo seleccionado.
class AssignmentsPage extends ConsumerWidget {
  const AssignmentsPage({super.key});

  static const _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final assignmentsAsync = ref.watch(assignmentsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignaciones'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AssignmentFormPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: Column(
        children: [
          // --- Selector de periodo ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.withValues(alpha: 0.05),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_months[period.month - 1]} ${period.year}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => _pickPeriod(context, ref, period),
                  child: const Text('Cambiar'),
                ),
              ],
            ),
          ),

          // --- Lista de carpetas ---
          Expanded(
            child: assignmentsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error al cargar:\n$err',
                      textAlign: TextAlign.center),
                ),
              ),
              data: (assignments) {
                if (assignments.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay asignaciones en este periodo.\n'
                        'Usa el botón "Nueva" para crear una.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: assignments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final a = assignments[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade100,
                        child: const Icon(Icons.folder_shared,
                            color: Colors.teal),
                      ),
                      title: Text(a.auxiliarName,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_buildSummary(a)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AssignmentDetailPage(assignment: a),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Resumen corto de lo que tiene la carpeta.
  String _buildSummary(AssignmentModel a) {
    final parts = <String>[];
    if (a.areas.isNotEmpty) {
      parts.add('${a.areas.length} área(s)');
    }
    if (a.ambulances.isNotEmpty) {
      parts.add('${a.ambulances.length} ambulancia(s)');
    }
    return parts.isEmpty ? 'Sin elementos' : parts.join(' · ');
  }

  /// Selector de mes y año.
  void _pickPeriod(BuildContext context, WidgetRef ref, Period current) {
    int selectedYear = current.year;
    int selectedMonth = current.month;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).viewPadding.bottom +
                    24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seleccionar periodo',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Mes',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(12, (i) {
                      return DropdownMenuItem(
                        value: i + 1,
                        child: Text(_months[i]),
                      );
                    }),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedMonth = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Año',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(5, (i) {
                      final year = DateTime.now().year - 2 + i;
                      return DropdownMenuItem(
                        value: year,
                        child: Text('$year'),
                      );
                    }),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedYear = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        ref
                            .read(selectedPeriodProvider.notifier)
                            .setPeriod(selectedYear, selectedMonth);
                        Navigator.pop(context);
                      },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
