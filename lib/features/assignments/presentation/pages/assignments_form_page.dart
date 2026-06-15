import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../catalogs/presentation/providers/area_providers.dart';
import '../../../catalogs/presentation/providers/ambulance_provider.dart';
import '../../../catalogs/presentation/providers/supply_providers.dart';
import '../providers/assignment_providers.dart';

/// Formulario para que el jefe cree una nueva responsabilidad.
class AssignmentFormPage extends ConsumerStatefulWidget {
  const AssignmentFormPage({super.key});

  @override
  ConsumerState<AssignmentFormPage> createState() =>
      _AssignmentFormPageState();
}

class _AssignmentFormPageState extends ConsumerState<AssignmentFormPage> {
  String? _auxiliarId;
  String? _areaId;
  String? _ambulanceId;

  // Insumos elegidos: {supply_id: cantidad}
  final Map<String, int> _selectedSupplies = {};

  final _responsibilitiesController = TextEditingController();
  final _objectivesController = TextEditingController();
  final _observationsController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _responsibilitiesController.dispose();
    _objectivesController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auxiliaresAsync = ref.watch(auxiliaresListProvider);
    final areasAsync = ref.watch(areasListProvider);
    final ambulancesAsync = ref.watch(ambulancesListProvider);
    final suppliesAsync = ref.watch(suppliesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva responsabilidad'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Auxiliar (obligatorio) ---
            auxiliaresAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error auxiliares: $e'),
              data: (auxiliares) {
                return DropdownButtonFormField<String>(
                  initialValue: _auxiliarId,
                  decoration: const InputDecoration(
                    labelText: 'Auxiliar *',
                    border: OutlineInputBorder(),
                  ),
                  items: auxiliares.map((aux) {
                    return DropdownMenuItem(
                      value: aux['id'] as String,
                      child: Text(aux['full_name'] as String),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _auxiliarId = v),
                );
              },
            ),
            const SizedBox(height: 16),

            // --- Área (obligatoria) ---
            areasAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error áreas: $e'),
              data: (areas) {
                final activeAreas =
                    areas.where((a) => a.isActive).toList();
                return DropdownButtonFormField<String>(
                  initialValue: _areaId,
                  decoration: const InputDecoration(
                    labelText: 'Área *',
                    border: OutlineInputBorder(),
                  ),
                  items: activeAreas.map((area) {
                    return DropdownMenuItem(
                      value: area.id,
                      child: Text(area.name),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _areaId = v),
                );
              },
            ),
            const SizedBox(height: 16),

            // --- Ambulancia (opcional) ---
            ambulancesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error ambulancias: $e'),
              data: (ambulances) {
                return DropdownButtonFormField<String>(
                  initialValue: _ambulanceId,
                  decoration: const InputDecoration(
                    labelText: 'Ambulancia (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Ninguna'),
                    ),
                    ...ambulances.map((amb) {
                      return DropdownMenuItem(
                        value: amb.id,
                        child: Text(amb.plate),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _ambulanceId = v),
                );
              },
            ),
            const SizedBox(height: 24),

            // --- Insumos con cantidad ---
            const Text('Insumos',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            suppliesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error insumos: $e'),
              data: (supplies) {
                final activeSupplies =
                    supplies.where((s) => s.isActive).toList();
                return Column(
                  children: activeSupplies.map((supply) {
                    final isSelected =
                        _selectedSupplies.containsKey(supply.id);
                    final quantity = _selectedSupplies[supply.id] ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: Colors.teal,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedSupplies[supply.id] = 1;
                                  } else {
                                    _selectedSupplies.remove(supply.id);
                                  }
                                });
                              },
                            ),
                            Expanded(child: Text(supply.name)),
                            if (isSelected) ...[
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: quantity > 1
                                    ? () => setState(() =>
                                        _selectedSupplies[supply.id] =
                                            quantity - 1)
                                    : null,
                              ),
                              Text('$quantity',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => setState(() =>
                                    _selectedSupplies[supply.id] =
                                        quantity + 1),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),

            // --- Campos de texto opcionales ---
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

            // --- Botón guardar ---
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
                    : const Text('Crear responsabilidad',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    // Validación de campos obligatorios.
    if (_auxiliarId == null || _areaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auxiliar y área son obligatorios.')),
      );
      return;
    }

    final period = ref.read(selectedPeriodProvider);
    final repo = ref.read(assignmentRepositoryProvider);

    setState(() => _saving = true);

    try {
      // Validación del límite de 5 responsabilidades por auxiliar/periodo.
      final count = await repo.countForAuxiliar(
        auxiliarId: _auxiliarId!,
        year: period.year,
        month: period.month,
      );
      if (count >= 5) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Este auxiliar ya tiene 5 responsabilidades en el periodo (máximo permitido).'),
            ),
          );
        }
        return;
      }

      // Obtener el id del jefe actual (quien asigna).
      final currentUser =
          ref.read(authRepositoryProvider).currentUser;

      await repo.create(
        auxiliarId: _auxiliarId!,
        areaId: _areaId!,
        ambulanceId: _ambulanceId,
        year: period.year,
        month: period.month,
        responsibilities: _responsibilitiesController.text.trim().isEmpty
            ? null
            : _responsibilitiesController.text.trim(),
        objectives: _objectivesController.text.trim().isEmpty
            ? null
            : _objectivesController.text.trim(),
        observations: _observationsController.text.trim().isEmpty
            ? null
            : _observationsController.text.trim(),
        supplies: _selectedSupplies,
        assignedBy: currentUser!.id,
      );

      ref.invalidate(assignmentsListProvider);
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