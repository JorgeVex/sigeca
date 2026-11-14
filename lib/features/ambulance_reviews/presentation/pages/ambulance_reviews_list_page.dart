import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../assignments/presentation/providers/assignment_providers.dart';
import '../../../assignments/data/models/assignment_model.dart';
import '../providers/ambulance_review_providers.dart';
import '../../data/models/ambulance_reviews.dart';
import 'ambulance_review_detail_page.dart';

const _months = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
];

/// Pantalla de revisión de ambulancias.
/// El auxiliar elige una ambulancia asignada y ve/crea sus revisiones.
class AmbulanceReviewsListPage extends ConsumerWidget {
  const AmbulanceReviewsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myAssignmentAsync = ref.watch(myAssignmentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisión de ambulancias'),
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
          if (assignment == null || assignment.ambulances.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping_outlined,
                        size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No tienes ambulancias asignadas este mes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            children: [
              const Text(
                'Selecciona una ambulancia para revisar su inventario '
                'y fechas de vencimiento.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...assignment.ambulances.map((amb) => _AmbulanceCard(
                    ambulance: amb,
                  )),
            ],
          );
        },
      ),
    );
  }
}

/// Tarjeta expandible de una ambulancia con su histórico de revisiones.
class _AmbulanceCard extends ConsumerWidget {
  final AssignmentAmbulanceItem ambulance;
  const _AmbulanceCard({required this.ambulance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync =
        ref.watch(ambulanceReviewsProvider(ambulance.ambulanceId));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping, color: Colors.teal),
                const SizedBox(width: 8),
                Text('Ambulancia ${ambulance.plate}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),

            // Histórico de revisiones.
            reviewsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e'),
              data: (reviews) {
                return Column(
                  children: [
                    if (reviews.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Sin revisiones todavía.',
                            style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...reviews.map((r) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              r.isCompleted
                                  ? Icons.check_circle
                                  : Icons.pending,
                              color:
                                  r.isCompleted ? Colors.green : Colors.orange,
                            ),
                            title: Text(
                                '${_months[r.periodMonth - 1]} ${r.periodYear}'),
                            subtitle: Text(r.isCompleted
                                ? 'Completada'
                                : 'En progreso'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openReview(context, ref, r),
                          )),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva revisión'),
                        onPressed: () => _createReview(context, ref),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openReview(
      BuildContext context, WidgetRef ref, AmbulanceReview review) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AmbulanceReviewDetailPage(
          review: review,
          plate: ambulance.plate,
        ),
      ),
    ).then((_) {
      ref.invalidate(ambulanceReviewsProvider(ambulance.ambulanceId));
    });
  }

  Future<void> _createReview(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final repo = ref.read(ambulanceReviewRepositoryProvider);
    try {
      final review = await repo.createReview(
        ambulanceId: ambulance.ambulanceId,
        periodYear: now.year,
        periodMonth: now.month,
      );
      ref.invalidate(ambulanceReviewsProvider(ambulance.ambulanceId));
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AmbulanceReviewDetailPage(
              review: review,
              plate: ambulance.plate,
            ),
          ),
        ).then((_) {
          ref.invalidate(ambulanceReviewsProvider(ambulance.ambulanceId));
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear revisión: $e')),
        );
      }
    }
  }
}