import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/assignment_model.dart';
import '../providers/assignment_providers.dart';

/// Pantalla de detalle de una carpeta de asignación.
/// Muestra áreas, ambulancias, insumos y notas del auxiliar.
class AssignmentDetailPage extends ConsumerWidget {
  final AssignmentModel assignment;
  const AssignmentDetailPage({super.key, required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliesAsync = ref.watch(
      assignmentSuppliesProvider(assignment.id),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(assignment.auxiliarName),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar carpeta',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Áreas ---
          _SectionTitle(icon: Icons.local_hospital, title: 'Áreas'),
          if (assignment.areas.isEmpty)
            const _EmptyHint('Sin áreas asignadas')
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
          _SectionTitle(icon: Icons.local_shipping, title: 'Ambulancias'),
          if (assignment.ambulances.isEmpty)
            const _EmptyHint('Sin ambulancias asignadas')
          else
            ...assignment.ambulances.map((amb) => Card(
                  child: ListTile(
                    leading:
                        const Icon(Icons.local_shipping, color: Colors.teal),
                    title: Text(amb.plate),
                  ),
                )),
          const SizedBox(height: 16),

          // --- Insumos ---
          _SectionTitle(icon: Icons.inventory_2, title: 'Insumos'),
          suppliesAsync.when(
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => Text('Error al cargar insumos: $e'),
            data: (supplies) {
              if (supplies.isEmpty) {
                return const _EmptyHint('Sin insumos asignados');
              }
              return Column(
                children: supplies
                    .map((s) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.medical_services,
                                color: Colors.teal),
                            title: Text(s.supplyName),
                            trailing: Text(
                              'x${s.quantity}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),

          // --- Notas ---
          if (assignment.responsibilities != null ||
              assignment.objectives != null ||
              assignment.observations != null) ...[
            _SectionTitle(icon: Icons.notes, title: 'Notas'),
            if (assignment.responsibilities != null)
              _NoteCard(
                  label: 'Responsabilidades',
                  text: assignment.responsibilities!),
            if (assignment.objectives != null)
              _NoteCard(label: 'Objetivos', text: assignment.objectives!),
            if (assignment.observations != null)
              _NoteCard(
                  label: 'Observaciones', text: assignment.observations!),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar carpeta'),
        content: Text(
            '¿Eliminar toda la asignación de ${assignment.auxiliarName}? '
            'Se borrarán sus áreas, ambulancias e insumos de este periodo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final repo = ref.read(assignmentRepositoryProvider);
              try {
                await repo.delete(assignment.id);
                ref.invalidate(assignmentsListProvider);
                ref.invalidate(assignedAreaIdsProvider);
                ref.invalidate(assignedAmbulanceIdsProvider);
                ref.invalidate(assignedAuxiliarIdsProvider);
                if (context.mounted) {
                  Navigator.pop(context); // cierra el diálogo
                  Navigator.pop(context); // vuelve a la lista
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Título de sección con ícono.
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
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
}

/// Texto gris para secciones vacías.
class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }
}

/// Tarjeta para una nota de texto.
class _NoteCard extends StatelessWidget {
  final String label;
  final String text;
  const _NoteCard({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 4),
            Text(text),
          ],
        ),
      ),
    );
  }
}