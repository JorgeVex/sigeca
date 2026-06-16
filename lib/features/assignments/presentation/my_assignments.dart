import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/assignment_providers.dart';
import '../presentation/pages/report_weeks_page.dart';

/// Pantalla del auxiliar: ve su carpeta del mes y la acepta.
class MyAssignmentPage extends ConsumerWidget {
  const MyAssignmentPage({super.key});

  static const _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final myAssignmentAsync = ref.watch(myAssignmentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis asignaciones'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: myAssignmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar:\n$err',
                textAlign: TextAlign.center),
          ),
        ),
        data: (assignment) {
          // Sin asignación este mes.
          if (assignment == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inbox, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes asignaciones para ${_months[period.month - 1]} ${period.year}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final suppliesAsync =
              ref.watch(assignmentSuppliesProvider(assignment.id));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Banner de estado ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: assignment.accepted
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: assignment.accepted
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      assignment.accepted
                          ? Icons.check_circle
                          : Icons.pending_actions,
                      color:
                          assignment.accepted ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        assignment.accepted
                            ? 'Asignación aceptada. Ya puedes generar reportes.'
                            : 'Revisa tu asignación y acéptala para habilitar los reportes.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '${_months[period.month - 1]} ${period.year}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // --- Áreas ---
              _sectionTitle(Icons.local_hospital, 'Áreas'),
              if (assignment.areas.isEmpty)
                _emptyHint('Sin áreas asignadas')
              else
                ...assignment.areas.map((area) => Card(
                      child: ListTile(
                        leading: Icon(
                          area.category == 'sala'
                              ? Icons.meeting_room
                              : Icons.assignment_turned_in,
                          color: Colors.teal,
                        ),
                        title: Text(area.areaName),
                        subtitle: Text(
                            area.category == 'sala' ? 'Sala' : 'Obligación'),
                      ),
                    )),
              const SizedBox(height: 16),

              // --- Ambulancias ---
              _sectionTitle(Icons.local_shipping, 'Ambulancias'),
              if (assignment.ambulances.isEmpty)
                _emptyHint('Sin ambulancias asignadas')
              else
                ...assignment.ambulances.map((amb) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_shipping,
                            color: Colors.teal),
                        title: Text(amb.plate),
                      ),
                    )),
              const SizedBox(height: 16),

              // --- Insumos ---
              _sectionTitle(Icons.inventory_2, 'Insumos'),
              suppliesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Error: $e'),
                data: (supplies) {
                  if (supplies.isEmpty) {
                    return _emptyHint('Sin insumos asignados');
                  }
                  return Column(
                    children: supplies
                        .map((s) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.medical_services,
                                    color: Colors.teal),
                                title: Text(s.supplyName),
                                trailing: Text('x${s.quantity}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),

              // --- Indicaciones ---
              if (assignment.observations != null) ...[
                _sectionTitle(Icons.warning_amber, 'Indicaciones'),
                Card(
                  color: Colors.amber.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(assignment.observations!),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // --- Botón aceptar (solo si NO está aceptada) ---
              if (!assignment.accepted)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Aceptar asignación',
                        style: TextStyle(fontSize: 16)),
                    onPressed: () =>
                        _confirmAccept(context, ref, assignment.id),
                  ),
                ),

              // --- Botón de reportes (solo si SÍ está aceptada) ---
              if (assignment.accepted)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.description),
                    label: const Text('Hacer reportes',
                        style: TextStyle(fontSize: 16)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ReportWeeksPage(assignment: assignment),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }

  void _confirmAccept(
      BuildContext context, WidgetRef ref, String assignmentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aceptar asignación'),
        content: const Text(
            '¿Confirmas que revisaste tu asignación y estás de acuerdo? '
            'Una vez aceptada, podrás generar tus reportes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final repo = ref.read(assignmentRepositoryProvider);
              try {
                await repo.acceptAssignment(assignmentId);
                ref.invalidate(myAssignmentProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Aceptar',
                style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }
}