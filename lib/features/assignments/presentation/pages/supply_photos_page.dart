import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/assignment_supply_model.dart';
import '../../data/models/supply_photo_model.dart';
import '../../data/repositories/report_repository.dart';
import '../providers/report_providers.dart';
import '../../../../core/services/camera_service.dart';

/// Pantalla para documentar un insumo: tomar 1-5 fotos y marcarlo listo.
class SupplyPhotosPage extends ConsumerStatefulWidget {
  final AssignmentSupplyModel supply;
  final int weekNumber;
  final String assignmentId;

  const SupplyPhotosPage({
    super.key,
    required this.supply,
    required this.weekNumber,
    required this.assignmentId,
  });

  @override
  ConsumerState<SupplyPhotosPage> createState() => _SupplyPhotosPageState();
}

class _SupplyPhotosPageState extends ConsumerState<SupplyPhotosPage> {
  final CameraService _cameraService = CameraService();
  bool _uploading = false;

  Future<void> _takePhoto(int currentCount) async {
    if (currentCount >= ReportRepository.maxSupplyPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Máximo ${ReportRepository.maxSupplyPhotos} fotos por insumo.')),
      );
      return;
    }

    final photo = await _cameraService.takePhoto();
    if (photo == null) return;

    setState(() => _uploading = true);
    try {
      final repo = ref.read(reportRepositoryProvider);
      await repo.addSupplyPhoto(
        photo: photo,
        assignmentSupplyId: widget.supply.id,
        supplyId: widget.supply.supplyId,
      );
      ref.invalidate(supplyPhotosProvider(widget.supply.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deletePhoto(SupplyPhoto photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Eliminar esta foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final repo = ref.read(reportRepositoryProvider);
      await repo.removeSupplyPhoto(
        photoId: photo.id,
        photoPath: photo.photoUrl,
      );
      ref.invalidate(supplyPhotosProvider(widget.supply.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _markDocumented(int photoCount) async {
    if (photoCount < ReportRepository.minSupplyPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Agrega al menos ${ReportRepository.minSupplyPhotos} foto para marcar como documentado.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar como documentado'),
        content: Text(
            'Confirmas que documentaste "${widget.supply.supplyName}". '
            'Quedará registrado en la semana ${widget.weekNumber} y no '
            'se volverá a pedir este mes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar',
                style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final repo = ref.read(reportRepositoryProvider);
      await repo.markSupplyDocumented(
        assignmentSupplyId: widget.supply.id,
        weekNumber: widget.weekNumber,
      );
      ref.invalidate(reportSuppliesProvider(widget.assignmentId));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(supplyPhotosProvider(widget.supply.id));
    final storageService = ref.watch(storageServiceProvider);
    final alreadyDocumented = widget.supply.documented;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supply.supplyName),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: photosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (photos) {
          return Column(
            children: [
              // Info del insumo.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.teal.withValues(alpha: 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cantidad asignada: ${widget.supply.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      alreadyDocumented
                          ? 'Documentado en la semana ${widget.supply.documentedWeek ?? '-'}.'
                          : '${photos.length} de ${ReportRepository.minSupplyPhotos}-${ReportRepository.maxSupplyPhotos} fotos.',
                      style: TextStyle(
                        color: alreadyDocumented
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: photos.isEmpty
                    ? const Center(
                        child: Text('Aún no hay fotos.',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: photos.length,
                        itemBuilder: (context, index) {
                          final photo = photos[index];
                          return _SupplyThumbnail(
                            photo: photo,
                            storageService: storageService,
                            canDelete: !alreadyDocumented,
                            onDelete: () => _deletePhoto(photo),
                          );
                        },
                      ),
              ),
              // Botón de marcar documentado (solo si no lo está).
// Botones inferiores (solo si no está documentado).
              if (!alreadyDocumented)
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: MediaQuery.of(context).viewPadding.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tomar foto.
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _uploading
                              ? null
                              : () => _takePhoto(photos.length),
                          icon: _uploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.camera_alt),
                          label: Text(_uploading ? 'Subiendo...' : 'Tomar foto',
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Marcar como documentado.
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: photos.isNotEmpty
                                ? Colors.green
                                : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Marcar como documentado',
                              style: TextStyle(fontSize: 16)),
                          onPressed: photos.isNotEmpty
                              ? () => _markDocumented(photos.length)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Miniatura de una foto de insumo (URL firmada, bucket privado).
class _SupplyThumbnail extends StatelessWidget {
  final SupplyPhoto photo;
  final dynamic storageService;
  final bool canDelete;
  final VoidCallback onDelete;

  const _SupplyThumbnail({
    required this.photo,
    required this.storageService,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: storageService.getSignedUrl(photo.photoUrl),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
                child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(snapshot.data!, fit: BoxFit.cover),
            ),
            if (canDelete)
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}