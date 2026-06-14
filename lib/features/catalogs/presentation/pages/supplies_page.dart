import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/supply_model.dart';
import '../providers/supply_providers.dart';

/// Pantalla de gestión del catálogo de insumos (CRUD).
class SuppliesPage extends ConsumerWidget {
  const SuppliesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliesAsync = ref.watch(suppliesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insumos'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () => _showSupplyForm(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: suppliesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar los insumos:\n$err',
                textAlign: TextAlign.center),
          ),
        ),
        data: (supplies) {
          if (supplies.isEmpty) {
            return const Center(child: Text('No hay insumos registrados.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: supplies.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final supply = supplies[index];
              return ListTile(
                leading: Icon(
                  supply.isActive ? Icons.check_circle : Icons.cancel,
                  color: supply.isActive ? Colors.teal : Colors.grey,
                ),
                title: Text(supply.name),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showSupplyForm(context, ref, supply: supply);
                    } else if (value == 'delete') {
                      _confirmDelete(context, ref, supply);
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

  /// Formulario para crear o editar un insumo.
  void _showSupplyForm(BuildContext context, WidgetRef ref,
      {SupplyModel? supply}) {
    final isEditing = supply != null;
    final nameController = TextEditingController(text: supply?.name ?? '');
    bool isActive = supply?.isActive ?? true;

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
                    isEditing ? 'Editar insumo' : 'Nuevo insumo',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Activo'),
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

                        final repo = ref.read(supplyRepositoryProvider);
                        try {
                          if (isEditing) {
                            await repo.update(
                              id: supply.id,
                              name: name,
                              isActive: isActive,
                            );
                          } else {
                            await repo.create(name: name);
                          }
                          ref.invalidate(suppliesListProvider);
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
      BuildContext context, WidgetRef ref, SupplyModel supply) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar insumo'),
        content: Text('¿Seguro que deseas eliminar "${supply.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final repo = ref.read(supplyRepositoryProvider);
              try {
                await repo.delete(supply.id);
                ref.invalidate(suppliesListProvider);
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