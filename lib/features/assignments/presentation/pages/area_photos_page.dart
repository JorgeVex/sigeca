import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/camera_service.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/report_repository.dart';
import '../providers/report_providers.dart';
import '../../../../core/services/watermark_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Pantalla de captura de fotos de un área dentro de un reporte.
/// Flujo: capturar varias fotos (pendientes) -> subir todas en paralelo.
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
  final WatermarkService _watermarkService = WatermarkService();

  // Fotos capturadas pero aún no subidas (crudas, sin marca de agua).
  final List<XFile> _pending = [];
  bool _uploading = false;

  /// Captura fotos en ráfaga: tras cada toma, reabre la cámara
  /// hasta que el usuario cancela o se alcanza el límite.
  Future<void> _capturePhotos(int uploadedCount) async {
    while (true) {
      final total = uploadedCount + _pending.length;
      if (total >= ReportRepository.maxPhotosPerArea) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Límite alcanzado (${ReportRepository.maxPhotosPerArea}). '
                    'Borra una para tomar otra.')),
          );
        }
        break;
      }

      final photo = await _cameraService.takePhoto();
      if (photo == null) break; // canceló -> termina la ráfaga

      setState(() => _pending.add(photo));
    }
  }

  /// Quita una foto pendiente (aún no subida).
  void _removePending(int index) {
    setState(() => _pending.removeAt(index));
  }

  /// Aplica marca de agua y sube todas las pendientes en paralelo.
  Future<void> _uploadAll(int uploadedCount) async {
    if (_pending.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final profile = ref.read(currentProfileProvider).value;
      final auxiliarName = profile?.fullName ?? 'Auxiliar';

      // Aplicar marca de agua a cada pendiente (en paralelo).
      final sealedFutures = _pending.map((photo) {
        return _watermarkService.applyWatermark(
          photo: photo,
          auxiliarName: auxiliarName,
          label: widget.areaGroup.areaName,
        );
      }).toList();

      final sealed = await Future.wait(sealedFutures);

      // Subir todas en paralelo + recontar al final.
      final repo = ref.read(reportRepositoryProvider);
      await repo.addPhotosBatch(
        photos: sealed,
        reportId: widget.report.id,
        areaGroupId: widget.areaGroup.id,
        areaId: widget.areaGroup.areaId,
      );

      if (mounted) {
        setState(() => _pending.clear());
        ref.invalidate(photosProvider(widget.areaGroup.id));
      }
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

  Future<void> _deleteUploaded(ReportPhoto photo, int currentCount) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Eliminar esta foto ya subida?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.red)),
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
      body: photosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (uploaded) {
          final uploadedCount = uploaded.length;
          final total = uploadedCount + _pending.length;

          return Column(
            children: [
              // Contador de progreso.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: uploadedCount >= ReportRepository.minPhotosPerArea
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                child: Text(
                  '$uploadedCount subidas'
                  '${_pending.isNotEmpty ? ' + ${_pending.length} pendientes' : ''}'
                  ' (de ${ReportRepository.minPhotosPerArea}-${ReportRepository.maxPhotosPerArea})'
                  '${uploadedCount >= ReportRepository.minPhotosPerArea ? ' — mínimo ✓' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // --- Fotos ya subidas ---
                    if (uploaded.isNotEmpty) ...[
                      const Text('Fotos subidas',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: uploaded.length,
                        itemBuilder: (context, index) {
                          final photo = uploaded[index];
                          return _PhotoThumbnail(
                            photo: photo,
                            storageService: storageService,
                            canDelete: canEdit && !_uploading,
                            onDelete: () =>
                                _deleteUploaded(photo, uploadedCount),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // --- Fotos pendientes (crudas, por subir) ---
                    if (_pending.isNotEmpty) ...[
                      const Text('Pendientes por subir',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _pending.length,
                        itemBuilder: (context, index) {
                          return _PendingThumbnail(
                            file: _pending[index],
                            canDelete: !_uploading,
                            onDelete: () => _removePending(index),
                          );
                        },
                      ),
                    ],

                    if (uploaded.isEmpty && _pending.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                              'Aún no hay fotos. Usa "Tomar fotos" para empezar.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                  ],
                ),
              ),

              // --- Botones inferiores ---
              if (canEdit)
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
                      // Tomar fotos (ráfaga).
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: (_uploading ||
                                  total >= ReportRepository.maxPhotosPerArea)
                              ? null
                              : () => _capturePhotos(uploadedCount),
                          icon: const Icon(Icons.camera_alt),
                          label: Text(
                              total >= ReportRepository.maxPhotosPerArea
                                  ? 'Límite alcanzado'
                                  : 'Tomar fotos',
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subir todas las pendientes.
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _pending.isNotEmpty
                                ? Colors.green
                                : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: (_pending.isEmpty || _uploading)
                              ? null
                              : () => _uploadAll(uploadedCount),
                          icon: _uploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.cloud_upload),
                          label: Text(
                              _uploading
                                  ? 'Subiendo...'
                                  : 'Subir ${_pending.length} foto(s)',
                              style: const TextStyle(fontSize: 16)),
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

/// Miniatura de una foto ya subida (URL firmada, bucket privado).
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

/// Miniatura de una foto pendiente (archivo local, aún sin subir).
class _PendingThumbnail extends StatelessWidget {
  final XFile file;
  final bool canDelete;
  final VoidCallback onDelete;

  const _PendingThumbnail({
    required this.file,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(file.path), fit: BoxFit.cover),
        ),
        // Marca de "pendiente".
        Positioned(
          bottom: 2,
          left: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            color: Colors.orange.withValues(alpha: 0.85),
            child: const Text('pendiente',
                style: TextStyle(color: Colors.white, fontSize: 9)),
          ),
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
                child:
                    const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }
}