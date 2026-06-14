import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/area_model.dart';
import '../providers/area_providers.dart';

/// Pantalla de gestión del catálogo de áreas (CRUD).
/// Solo el admin llega aquí; RLS protege las operaciones de escritura.
class AreasPage extends ConsumerWidget {
  const AreasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(areasListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Áreas'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () => _showAreaForm(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: areasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar las áreas:\n$err',
                textAlign: TextAlign.center),
          ),
        ),
        data: (areas) {
          if (areas.isEmpty) {
            return const Center(child: Text('No hay áreas registradas.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: areas.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final area = areas[index];
              return ListTile(
                leading: Icon(
                  area.isActive ? Icons.check_circle : Icons.cancel,
                  color: area.isActive ? Colors.teal : Colors.grey,
                ),
                title: Text(area.name),
                subtitle: area.description != null
                    ? Text(area.description!)
                    : null,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showAreaForm(context, ref, area: area);
                    } else if (value == 'delete') {
                      _confirmDelete(context, ref, area);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Muestra el formulario para crear o editar un área.
  /// Si recibe un 'area', es edición; si no, es creación.
  void _showAreaForm(BuildContext context, WidgetRef ref, {AreaModel? area}) {
    final isEditing = area != null;
    final nameController = TextEditingController(text: area?.name ?? '');
    final descController =
        TextEditingController(text: area?.description ?? '');
    bool isActive = area?.isActive ?? true;

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
                    isEditing ? 'Editar área' : 'Nueva área',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Activa'),
                      value: isActive,
                      activeColor: Colors.teal,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setModalState(() => isActive = v),
                    ),
                  ],
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
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        final desc = descController.text.trim();

                        final repo = ref.read(areaRepositoryProvider);
                        try {
                          if (isEditing) {
                            await repo.update(
                              id: area.id,
                              name: name,
                              description: desc.isEmpty ? null : desc,
                              isActive: isActive,
                            );
                          } else {
                            await repo.create(
                              name: name,
                              description: desc.isEmpty ? null : desc,
                            );
                          }
                          // Recarga la lista y cierra el formulario.
                          ref.invalidate(areasListProvider);
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

  /// Diálogo de confirmación antes de eliminar.
  void _confirmDelete(BuildContext context, WidgetRef ref, AreaModel area) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar área'),
        content: Text('¿Seguro que deseas eliminar "${area.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final repo = ref.read(areaRepositoryProvider);
              try {
                await repo.delete(area.id);
                ref.invalidate(areasListProvider);
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