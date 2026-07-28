import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/assignment_model.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/report_repository.dart';
import '../providers/report_providers.dart';
import 'area_photos_page.dart';
import 'supply_photos_page.dart';

/// Pantalla de las áreas de un reporte semanal.
/// Muestra el progreso de fotos por área y permite cerrar la semana.
/// Incluye una sección opcional de insumos.
class ReportAreasPage extends ConsumerWidget {
  final ReportModel report;
  final AssignmentModel assignment;

  const ReportAreasPage({
    super.key,
    required this.report,
    required this.assignment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(areaGroupsProvider(report.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Semana ${report.weekNumber}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar:\n$err',
                textAlign: TextAlign.center),
          ),
        ),
        data: (groups) {
          // ¿Todas las áreas tienen el mínimo?
          final allComplete = groups.every(
              (g) => g.photoCount >= ReportRepository.minPhotosPerArea);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      report.isCompleted
                          ? 'Esta semana está completada.'
                          : 'Toma entre ${ReportRepository.minPhotosPerArea} y '
                              '${ReportRepository.maxPhotosPerArea} fotos por área.',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ...groups.map((group) {
                      final hasMin = group.photoCount >=
                          ReportRepository.minPhotosPerArea;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(
                            group.category == 'sala'
                                ? Icons.meeting_room
                                : Icons.assignment_turned_in,
                            color: hasMin ? Colors.green : Colors.teal,
                          ),
                          title: Text(group.areaName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${group.photoCount} foto(s)'
                            '${hasMin ? ' ✓' : ' — faltan ${ReportRepository.minPhotosPerArea - group.photoCount}'}',
                            style: TextStyle(
                              color: hasMin ? Colors.green : Colors.orange,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AreaPhotosPage(
                                  report: report,
                                  areaGroup: group,
                                ),
                              ),
                            ).then((_) {
                              // Al volver, refrescar los contadores.
                              ref.invalidate(areaGroupsProvider(report.id));
                            });
                          },
                        ),
                      );
                    }),

                    // --- Sección de insumos (opcional) ---
                    const SizedBox(height: 24),
                    _buildSuppliesSection(context, ref),
                  ],
                ),
              ),

              // Botón de cerrar semana (solo si no está completada).
              if (!report.isCompleted)
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: MediaQuery.of(context).viewPadding.bottom + 16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            allComplete ? Colors.teal : Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.lock),
                      label: Text(allComplete
                          ? 'Cerrar semana ${report.weekNumber}'
                          : 'Completa todas las áreas para cerrar'),
                      onPressed: allComplete
                          ? () => _confirmComplete(context, ref)
                          : null,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Sección de insumos: muestra los insumos de la carpeta con su estado.
  /// Documentar insumos es opcional y no bloquea el cierre de la semana.
  Widget _buildSuppliesSection(BuildContext context, WidgetRef ref) {
    final suppliesAsync =
        ref.watch(reportSuppliesProvider(assignment.id));

    return suppliesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error al cargar insumos: $e'),
      data: (supplies) {
        if (supplies.isEmpty) {
          return const SizedBox.shrink(); // sin insumos, no muestra nada
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                const Text('Insumos (opcional)',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Documenta cada insumo cuando lo tengas listo, en la semana '
              'que prefieras. No es obligatorio para cerrar la semana.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...supplies.map((supply) {
              final done = supply.documented;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    done ? Icons.check_circle : Icons.medical_services,
                    color: done ? Colors.green : Colors.teal,
                  ),
                  title: Text(supply.supplyName),
                  subtitle: Text(
                    done
                        ? 'Documentado (semana ${supply.documentedWeek ?? '-'})'
                        : 'Cantidad: ${supply.quantity} — pendiente',
                    style: TextStyle(
                      color: done ? Colors.green : Colors.orange,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupplyPhotosPage(
                          supply: supply,
                          weekNumber: report.weekNumber,
                          assignmentId: assignment.id,
                        ),
                      ),
                    ).then((_) {
                      // Al volver, refrescar el estado de los insumos.
                      ref.invalidate(reportSuppliesProvider(assignment.id));
                    });
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _confirmComplete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cerrar semana ${report.weekNumber}'),
        content: const Text(
            '¿Confirmas que completaste todas las áreas de esta semana? '
            'Una vez cerrada, no podrás agregar más fotos y se habilitará '
            'la siguiente semana.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final repo = ref.read(reportRepositoryProvider);
              try {
                await repo.completeWeek(report.id);
                ref.invalidate(reportsListProvider(assignment.id));
                if (context.mounted) {
                  Navigator.pop(context); // cierra diálogo
                  Navigator.pop(context); // vuelve a las semanas
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              }
            },
            child: const Text('Cerrar semana',
                style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }
}