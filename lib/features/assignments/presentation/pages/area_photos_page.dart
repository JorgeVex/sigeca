import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/camera_service.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/report_repository.dart';
import '../providers/report_providers.dart';

/// Pantalla de captura de fotos de un área dentro de un reporte.
class AreaPhotosPage extends ConsumerStatefulWidget {
  final ReportModel report;
  final ReportAreaPhotos areaGroup;

  const AreaPhotosPage({
    super.key,
    required this.report,
    required this.areaGroup,
  });

  @override
  ConsumerState<AreaPhotosPage> createState() => _AreaPhotosPageState();
}

class _AreaPhotosPageState extends ConsumerState<AreaPhotosPage> {
  final CameraService _cameraService = CameraService();
  bool _uploading = false;

  Future<void> _takePhoto(int currentCount) async {
    // Verificar el máximo.
    if (currentCount >= ReportRepository.maxPhotosPerArea) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Máximo ${ReportRepository.maxPhotosPerArea} fotos por área.')),
      );
      return;
    }

    final photo = await _cameraService.takePhoto();
    if (photo == null) return; // canceló

    setState(() => _uploading = true);
    try {
      final repo = ref.read(reportRepositoryProvider);
      await repo.addPhoto(
        photo: photo,
        reportId: widget.report.id,
        areaGroupId: widget.areaGroup.id,
        areaId: widget.areaGroup.areaId,
        currentCount: currentCount,
      );
      ref.invalidate(photosProvider(widget.areaGroup.id));
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

  Future<void> _deletePhoto(ReportPhoto photo, int currentCount) async {
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
      await repo.removePhoto(
        photoId: photo.id,
        photoPath: photo.photoUrl,
        areaGroupId: widget.areaGroup.id,
        currentCount: currentCount,
      );
      ref.invalidate(photosProvider(widget.areaGroup.id));
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
    final photosAsync = ref.watch(photosProvider(widget.areaGroup.id));
    final storageService = ref.watch(storageServiceProvider);
    final canEdit = !widget.report.isCompleted;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.areaGroup.areaName),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: canEdit
          ? photosAsync.maybeWhen(
              data: (photos) => FloatingActionButton.extended(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                onPressed:
                    _uploading ? null : () => _takePhoto(photos.length),
                icon: _uploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(_uploading ? 'Subiendo...' : 'Tomar foto'),
              ),
              orElse: () => null,
            )
          : null,
      body: photosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (photos) {
          return Column(
            children: [
              // Contador de progreso.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: photos.length >= ReportRepository.minPhotosPerArea
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                child: Text(
                  '${photos.length} de ${ReportRepository.minPhotosPerArea}-${ReportRepository.maxPhotosPerArea} fotos'
                  '${photos.length >= ReportRepository.minPhotosPerArea ? ' — mínimo alcanzado ✓' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: photos.isEmpty
                    ? const Center(
                        child: Text('Aún no hay fotos. Usa el botón para tomar.',
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
                          return _PhotoThumbnail(
                            photo: photo,
                            storageService: storageService,
                            canDelete: canEdit,
                            onDelete: () =>
                                _deletePhoto(photo, photos.length),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Miniatura de una foto, cargada con URL firmada (bucket privado).
class _PhotoThumbnail extends StatelessWidget {
  final ReportPhoto photo;
  final dynamic storageService; // StorageService
  final bool canDelete;
  final VoidCallback onDelete;

  const _PhotoThumbnail({
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