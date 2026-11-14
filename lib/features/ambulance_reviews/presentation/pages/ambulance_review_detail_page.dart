import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ambulance_reviews.dart';
import '../providers/ambulance_review_providers.dart';

/// Formulario de una revisión: lista los ítems agrupados por categoría.
/// Cada ítem se edita en un diálogo (cantidad, lote, vencimiento, N/A).
class AmbulanceReviewDetailPage extends ConsumerWidget {
  final AmbulanceReview review;
  final String plate;

  const AmbulanceReviewDetailPage({
    super.key,
    required this.review,
    required this.plate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(ambulanceReviewItemsProvider(review.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Revisión — $plate'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (items) {
          // Agrupar por categoría.
          final Map<String, List<AmbulanceReviewItem>> byCategory = {};
          for (final it in items) {
            byCategory.putIfAbsent(it.category, () => []).add(it);
          }
          final categories = byCategory.keys.toList()..sort();

          // Resumen del semáforo.
          final rojos = items
              .where((i) => i.semaphore == AmbulanceSemaphore.red)
              .length;
          final amarillos = items
              .where((i) => i.semaphore == AmbulanceSemaphore.yellow)
              .length;

          return Column(
            children: [
              // Barra resumen del semáforo.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _semaphoreChip(Colors.red, '$rojos', 'Críticos'),
                    _semaphoreChip(Colors.orange, '$amarillos', 'Por vencer'),
                    _semaphoreChip(
                        Colors.grey, '${items.length}', 'Total ítems'),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 80,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final catItems = byCategory[cat]!;
                    return ExpansionTile(
                      title: Text(cat,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${catItems.length} ítems'),
                      children: catItems
                          .map((it) => _ItemTile(
                                item: it,
                                reviewId: review.id,
                                canEdit: !review.isCompleted,
                              ))
                          .toList(),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: review.isCompleted
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.check),
              label: const Text('Finalizar revisión'),
              onPressed: () => _confirmComplete(context, ref),
            ),
    );
  }

  Widget _semaphoreChip(Color color, String count, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(count,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  void _confirmComplete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar revisión'),
        content: const Text(
            '¿Confirmas que terminaste de revisar todos los ítems de esta '
            'ambulancia? Podrás seguir consultándola, pero quedará registrada '
            'como completada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final repo = ref.read(ambulanceReviewRepositoryProvider);
              try {
                await repo.completeReview(review.id);
                ref.invalidate(ambulanceReviewItemsProvider(review.id));
                if (context.mounted) {
                  Navigator.pop(context); // diálogo
                  Navigator.pop(context); // vuelve a la lista
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Finalizar',
                style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }
}

/// Fila de un ítem: muestra estado y abre el diálogo de edición.
class _ItemTile extends ConsumerWidget {
  final AmbulanceReviewItem item;
  final String reviewId;
  final bool canEdit;

  const _ItemTile({
    required this.item,
    required this.reviewId,
    required this.canEdit,
  });

  Color get _dotColor {
    switch (item.semaphore) {
      case AmbulanceSemaphore.green:
        return Colors.green;
      case AmbulanceSemaphore.yellow:
        return Colors.orange;
      case AmbulanceSemaphore.red:
        return Colors.red;
      case AmbulanceSemaphore.none:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venc = item.naFlag
        ? 'N/A'
        : (item.expiryDate != null
            ? '${item.expiryDate!.day.toString().padLeft(2, '0')}/'
                '${item.expiryDate!.month.toString().padLeft(2, '0')}/'
                '${item.expiryDate!.year}'
            : 'Sin fecha');

    return ListTile(
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
      ),
      title: Text(item.name, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        'Cant: ${item.quantity ?? '-'}  •  Lote: ${item.lote ?? '-'}  •  Vence: $venc',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: canEdit ? const Icon(Icons.edit, size: 18) : null,
      onTap: canEdit
          ? () => _editItem(context, ref)
          : null,
    );
  }

  Future<void> _editItem(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_ItemEditResult>(
      context: context,
      builder: (context) => _ItemEditDialog(item: item),
    );
    if (result == null) return;

    try {
      final repo = ref.read(ambulanceReviewRepositoryProvider);
      await repo.updateReviewItem(
        itemId: item.id,
        quantity: result.quantity,
        lote: result.lote,
        expiryDate: result.expiryDate,
        notes: result.notes,
        naFlag: result.naFlag,
      );
      ref.invalidate(ambulanceReviewItemsProvider(reviewId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

/// Resultado del diálogo de edición.
class _ItemEditResult {
  final int? quantity;
  final String? lote;
  final DateTime? expiryDate;
  final String? notes;
  final bool naFlag;
  _ItemEditResult({
    this.quantity,
    this.lote,
    this.expiryDate,
    this.notes,
    required this.naFlag,
  });
}

/// Diálogo para editar un ítem: cantidad, lote, vencimiento, N/A, notas.
class _ItemEditDialog extends StatefulWidget {
  final AmbulanceReviewItem item;
  const _ItemEditDialog({required this.item});

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
  late TextEditingController _qtyController;
  late TextEditingController _loteController;
  late TextEditingController _notesController;
  DateTime? _expiryDate;
  late bool _naFlag;

  @override
  void initState() {
    super.initState();
    _qtyController =
        TextEditingController(text: widget.item.quantity?.toString() ?? '');
    _loteController = TextEditingController(text: widget.item.lote ?? '');
    _notesController = TextEditingController(text: widget.item.notes ?? '');
    _expiryDate = widget.item.expiryDate;
    _naFlag = widget.item.naFlag;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _loteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.name, style: const TextStyle(fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle N/A.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('No aplica (N/A)'),
              subtitle: const Text('El ítem no tiene vencimiento/lote'),
              value: _naFlag,
              activeThumbColor: Colors.teal,
              onChanged: (v) => setState(() => _naFlag = v),
            ),
            const Divider(),
            // Cantidad.
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad física',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Lote (deshabilitado si N/A).
            TextField(
              controller: _loteController,
              enabled: !_naFlag,
              decoration: const InputDecoration(
                labelText: 'Lote',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Fecha de vencimiento (deshabilitada si N/A).
            InkWell(
              onTap: _naFlag ? null : _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Fecha de vencimiento',
                  border: const OutlineInputBorder(),
                  enabled: !_naFlag,
                ),
                child: Text(
                  _naFlag
                      ? 'N/A'
                      : (_expiryDate != null
                          ? '${_expiryDate!.day.toString().padLeft(2, '0')}/'
                              '${_expiryDate!.month.toString().padLeft(2, '0')}/'
                              '${_expiryDate!.year}'
                          : 'Seleccionar fecha'),
                  style: TextStyle(
                      color: _naFlag ? Colors.grey : Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Notas.
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Observaciones (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          onPressed: () {
            final qty = int.tryParse(_qtyController.text.trim());
            Navigator.pop(
              context,
              _ItemEditResult(
                quantity: qty,
                lote: _naFlag ? null : _loteController.text.trim(),
                expiryDate: _naFlag ? null : _expiryDate,
                notes: _notesController.text.trim().isEmpty
                    ? null
                    : _notesController.text.trim(),
                naFlag: _naFlag,
              ),
            );
          },
          child: const Text('Guardar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}