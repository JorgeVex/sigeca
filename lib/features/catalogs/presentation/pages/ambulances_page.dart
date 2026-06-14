import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ambulance_model.dart';
import '../providers/ambulance_provider.dart';

/// Pantalla de gestión del catálogo de ambulancias (CRUD).
class AmbulancesPage extends ConsumerWidget {
  const AmbulancesPage({super.key});

  // Opciones de estado posibles para una ambulancia.
  static const _statusOptions = ['activa', 'mantenimiento', 'inactiva'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ambulancesAsync = ref.watch(ambulancesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambulancias'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () => _showAmbulanceForm(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ambulancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar las ambulancias:\n$err',
                textAlign: TextAlign.center),
          ),
        ),
        data: (ambulances) {
          if (ambulances.isEmpty) {
            return const Center(
                child: Text('No hay ambulancias registradas.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: ambulances.length,
            itemBuilder: (context, index) {
              final amb = ambulances[index];
              return _AmbulanceCard(
                ambulance: amb,
                onEdit: () => _showAmbulanceForm(context, ref, ambulance: amb),
                onDelete: () => _confirmDelete(context, ref, amb),
                statusColor: _statusColor(amb.status),
                statusLabel: _statusLabel(amb.status),
              );
            },
          );
        },
      ),
    );
  }

  /// Color del ícono/indicador según el estado.
  Color _statusColor(String status) {
    switch (status) {
      case 'activa':
        return Colors.teal;
      case 'mantenimiento':
        return Colors.orange;
      case 'inactiva':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  /// Etiqueta legible (primera letra mayúscula).
  String _statusLabel(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }

  /// Formulario para crear o editar una ambulancia.
  void _showAmbulanceForm(BuildContext context, WidgetRef ref,
      {AmbulanceModel? ambulance}) {
    final isEditing = ambulance != null;
    final plateController =
        TextEditingController(text: ambulance?.plate ?? '');
    String status = ambulance?.status ?? 'activa';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 
                MediaQuery.of(context).viewPadding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Editar ambulancia' : 'Nueva ambulancia',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: plateController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Placa',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Selector de estado (dropdown con las 3 opciones).
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                    ),
                    items: _statusOptions.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(_statusLabel(s)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => status = value);
                      }
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
                      onPressed: () async {
                        final plate =
                            plateController.text.trim().toUpperCase();
                        if (plate.isEmpty) return;

                        final repo = ref.read(ambulanceRepositoryProvider);
                        try {
                          if (isEditing) {
                            await repo.update(
                              id: ambulance.id,
                              plate: plate,
                              status: status,
                            );
                          } else {
                            await repo.create(plate: plate, status: status);
                          }
                          ref.invalidate(ambulancesListProvider);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      child: Text(isEditing ? 'Guardar' : 'Crear'),
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

  /// Confirmación antes de eliminar.
  void _confirmDelete(
      BuildContext context, WidgetRef ref, AmbulanceModel ambulance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar ambulancia'),
        content:
            Text('¿Seguro que deseas eliminar la placa "${ambulance.plate}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final repo = ref.read(ambulanceRepositoryProvider);
              try {
                await repo.delete(ambulance.id);
                ref.invalidate(ambulancesListProvider);
                if (context.mounted) Navigator.pop(context);
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

/// Card visual de una ambulancia.
/// La sección de imagen está aislada para facilitar
/// el cambio a fotos reales (Supabase Storage) en el futuro.
class _AmbulanceCard extends StatelessWidget {
  final dynamic ambulance; // AmbulanceModel
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color statusColor;
  final String statusLabel;

  const _AmbulanceCard({
    required this.ambulance,
    required this.onEdit,
    required this.onDelete,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Sección de imagen (placeholder por ahora) ---
          // El día de mañana: reemplazar por Image.network(ambulance.photoUrl)
          Expanded(
            child: _buildImageSection(),
          ),

          // --- Sección de info ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ambulance.plate,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              statusLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sección de imagen. Aislada a propósito:
  /// cuando tengas fotos reales, solo cambias este método.
  Widget _buildImageSection() {
    return Container(
      color: Colors.teal.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          Icons.local_shipping,
          size: 56,
          color: Colors.teal.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}