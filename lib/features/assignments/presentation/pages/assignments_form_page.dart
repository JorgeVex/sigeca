import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../catalogs/presentation/providers/area_providers.dart';
import '../../../catalogs/presentation/providers/ambulance_provider.dart';
import '../../../catalogs/presentation/providers/supply_providers.dart';
import '../providers/assignment_providers.dart';

/// Formulario para crear la carpeta de un auxiliar:
/// varias áreas + varias ambulancias + insumos generales.
class AssignmentFormPage extends ConsumerStatefulWidget {
  const AssignmentFormPage({super.key});

  @override
  ConsumerState<AssignmentFormPage> createState() =>
      _AssignmentFormPageState();
}

class _AssignmentFormPageState extends ConsumerState<AssignmentFormPage> {
  String? _auxiliarId;

  // Áreas y ambulancias marcadas (sets de IDs).
  final Set<String> _selectedAreas = {};
  final Set<String> _selectedAmbulances = {};

  // Insumos: {supply_id: cantidad} + sus controladores de texto.
  final Map<String, int> _selectedSupplies = {};
  final Map<String, TextEditingController> _qtyControllers = {};

  final _responsibilitiesController = TextEditingController();
  final _objectivesController = TextEditingController();
  final _observationsController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _responsibilitiesController.dispose();
    _objectivesController.dispose();
    _observationsController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auxiliaresAsync = ref.watch(auxiliaresListProvider);
    final assignedAuxAsync = ref.watch(assignedAuxiliarIdsProvider);
    final areasAsync = ref.watch(areasListProvider);
    final ambulancesAsync = ref.watch(ambulancesListProvider);
    final suppliesAsync = ref.watch(suppliesListProvider);
    final assignedAreasAsync = ref.watch(assignedAreaIdsProvider);
    final assignedAmbulancesAsync = ref.watch(assignedAmbulanceIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva asignación'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Auxiliar (solo los que no tienen carpeta aún) ---
            const Text('Auxiliar *',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildAuxiliarDropdown(auxiliaresAsync, assignedAuxAsync),
            const SizedBox(height: 24),

            // --- Áreas (checkboxes, agrupadas, sin las tomadas) ---
            const Text('Áreas',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildAreasCheckboxes(areasAsync, assignedAreasAsync),
            const SizedBox(height: 24),

            // --- Ambulancias (checkboxes, sin las tomadas) ---
            const Text('Ambulancias',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildAmbulancesCheckboxes(
                ambulancesAsync, assignedAmbulancesAsync),
            const SizedBox(height: 24),

            // --- Insumos (checkbox + cantidad manual) ---
            const Text('Insumos',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildSuppliesCheckboxes(suppliesAsync),
            const SizedBox(height: 24),

            // --- Notas ---
            TextField(
              controller: _responsibilitiesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Responsabilidades (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _objectivesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Objetivos (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _observationsController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observaciones (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: _saving ? null : _handleSave,
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Crear asignación',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuxiliarDropdown(
      AsyncValue auxAsync, AsyncValue assignedAsync) {
    return auxAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data: (auxiliares) {
        return assignedAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (assignedIds) {
            final available = auxiliares
                .where((a) => !assignedIds.contains(a['id']))
                .toList();

            if (available.isEmpty) {
              return const Text(
                'Todos los auxiliares ya tienen asignación este periodo.',
                style: TextStyle(color: Colors.grey),
              );
            }

            final validId =
                available.any((a) => a['id'] == _auxiliarId)
                    ? _auxiliarId
                    : null;

            return DropdownButtonFormField<String>(
              initialValue: validId,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: available.map <DropdownMenuItem<String>>((aux) {
                return DropdownMenuItem<String>(
                  value: aux['id'] as String,
                  child: Text(aux['full_name'] as String),
                );
              }).toList(),
              onChanged: (v) => setState(() => _auxiliarId = v),
            );
          },
        );
      },
    );
  }

  Widget _buildAreasCheckboxes(
      AsyncValue areasAsync, AsyncValue assignedAsync) {
    return areasAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data: (areas) {
        return assignedAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (assignedIds) {
            final available = areas
                .where((a) => a.isActive && !assignedIds.contains(a.id))
                .toList();
            final salas =
                available.where((a) => a.category == 'sala').toList();
            final obligaciones =
                available.where((a) => a.category == 'obligacion').toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (salas.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Salas',
                        style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold)),
                  ),
                  ...salas.map((a) => CheckboxListTile(
                        title: Text(a.name),
                        value: _selectedAreas.contains(a.id),
                        activeColor: Colors.teal,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedAreas.add(a.id);
                            } else {
                              _selectedAreas.remove(a.id);
                            }
                          });
                        },
                      )),
                ],
                if (obligaciones.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Obligaciones',
                        style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold)),
                  ),
                  ...obligaciones.map((a) => CheckboxListTile(
                        title: Text(a.name),
                        value: _selectedAreas.contains(a.id),
                        activeColor: Colors.teal,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedAreas.add(a.id);
                            } else {
                              _selectedAreas.remove(a.id);
                            }
                          });
                        },
                      )),
                ],
                if (available.isEmpty)
                  const Text('No quedan áreas disponibles.',
                      style: TextStyle(color: Colors.grey)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAmbulancesCheckboxes(
      AsyncValue ambAsync, AsyncValue assignedAsync) {
    return ambAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data: (ambulances) {
        return assignedAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (assignedIds) {
            final available = ambulances
                .where((a) => !assignedIds.contains(a.id))
                .toList();

            if (available.isEmpty) {
              return const Text('No quedan ambulancias disponibles.',
                  style: TextStyle(color: Colors.grey));
            }

            return Column(
              children: available.map<Widget>((amb) {
                return CheckboxListTile(
                  title: Text(amb.plate),
                  value: _selectedAmbulances.contains(amb.id),
                  activeColor: Colors.teal,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedAmbulances.add(amb.id);
                      } else {
                        _selectedAmbulances.remove(amb.id);
                      }
                    });
                  },
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildSuppliesCheckboxes(AsyncValue suppliesAsync) {
    return suppliesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data: (supplies) {
        final active = 
        (supplies as List).where((s) => s.isActive).toList();
        return Column(
          children: active.map((supply) {
            final isSelected = _selectedSupplies.containsKey(supply.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      activeColor: Colors.teal,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedSupplies[supply.id] = 1;
                            _qtyControllers[supply.id] =
                                TextEditingController(text: '1');
                          } else {
                            _selectedSupplies.remove(supply.id);
                            _qtyControllers[supply.id]?.dispose();
                            _qtyControllers.remove(supply.id);
                          }
                        });
                      },
                    ),
                    Expanded(child: Text(supply.name)),
                    if (isSelected)
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _qtyControllers[supply.id],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'Cant.',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          onChanged: (value) {
                            _selectedSupplies[supply.id] =
                                int.tryParse(value) ?? 0;
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _handleSave() async {
    if (_auxiliarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un auxiliar.')),
      );
      return;
    }
    if (_selectedAreas.isEmpty && _selectedAmbulances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Asigna al menos un área o una ambulancia.')),
      );
      return;
    }
    if (_selectedSupplies.values.any((q) => q <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Las cantidades deben ser mayores a 0.')),
      );
      return;
    }

    final period = ref.read(selectedPeriodProvider);
    final repo = ref.read(assignmentRepositoryProvider);
    setState(() => _saving = true);

    try {
      final currentUser = ref.read(authRepositoryProvider).currentUser;

      await repo.createPackage(
        auxiliarId: _auxiliarId!,
        year: period.year,
        month: period.month,
        areaIds: _selectedAreas.toList(),
        ambulanceIds: _selectedAmbulances.toList(),
        supplies: _selectedSupplies,
        responsibilities: _responsibilitiesController.text.trim().isEmpty
            ? null
            : _responsibilitiesController.text.trim(),
        objectives: _objectivesController.text.trim().isEmpty
            ? null
            : _objectivesController.text.trim(),
        observations: _observationsController.text.trim().isEmpty
            ? null
            : _observationsController.text.trim(),
        assignedBy: currentUser!.id,
      );

      ref.invalidate(assignmentsListProvider);
      ref.invalidate(assignedAreaIdsProvider);
      ref.invalidate(assignedAmbulanceIdsProvider);
      ref.invalidate(assignedAuxiliarIdsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}