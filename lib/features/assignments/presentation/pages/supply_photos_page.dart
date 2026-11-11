import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/assignment_supply_model.dart';
import '../../data/models/supply_photo_model.dart';
import '../../data/repositories/report_repository.dart';
import '../providers/report_providers.dart';
import '../../../../core/services/camera_service.dart';
import '../../../../core/services/watermark_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Pantalla para documentar un insumo: tomar 1-5 fotos y marcarlo listo.
/// Flujo: capturar varias (pendientes) -> subir todas en paralelo.
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
  final WatermarkService _watermarkService = WatermarkService();

  final List<XFile> _pending = [];
  bool _uploading = false;

  /// Captura fotos en ráfaga hasta cancelar o llegar al límite.
  Future<void> _capturePhotos(int uploadedCount) async {
    while (true) {
      final total = uploadedCount + _pending.length;
      if (total >= ReportRepository.maxSupplyPhotos) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Límite alcanzado (${ReportRepository.maxSupplyPhotos}). '
                    'Borra una para tomar otra.')),
          );
        }
        break;
      }

      final photo = await _cameraService.takePhoto();
      if (photo == null) break;

      setState(() => _pending.add(photo));
    }
  }

  void _removePending(int index) {
    setState(() => _pending.removeAt(index));
  }

  /// Aplica marca de agua y sube todas las pendientes en paralelo.
  Future<void> _uploadAll() async {
    if (_pending.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final profile = ref.read(currentProfileProvider).value;
      final auxiliarName = profile?.fullName ?? 'Auxiliar';

      final sealedFutures = _pending.map((photo) {
        return _watermarkService.applyWatermark(
          photo: photo,
          auxiliarName: auxiliarName,
          label: widget.supply.supplyName,
        );
      }).toList();

      final sealed = await Future.wait(sealedFutures);

      final repo = ref.read(reportRepositoryProvider);
      await repo.addSupplyPhotosBatch(
        photos: sealed,
        assignmentSupplyId: widget.supply.id,
        supplyId: widget.supply.supplyId,
      );

      if (mounted) {
        setState(() => _pending.clear());
        ref.invalidate(supplyPhotosProvider(widget.supply.id));
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
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.red)),
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
        data: (uploaded) {
          final uploadedCount = uploaded.length;
          final total = uploadedCount + _pending.length;

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
                          : '$uploadedCount subidas'
                              '${_pending.isNotEmpty ? ' + ${_pending.length} pendientes' : ''}'
                              ' (de ${ReportRepository.minSupplyPhotos}-${ReportRepository.maxSupplyPhotos})',
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
                          return _SupplyThumbnail(
                            photo: photo,
                            storageService: storageService,
                            canDelete: !alreadyDocumented && !_uploading,
                            onDelete: () => _deletePhoto(photo),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // --- Pendientes por subir ---
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
                          child: Text('Aún no hay fotos.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                  ],
                ),
              ),

              // --- Botones inferiores (solo si no está documentado) ---
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
                                  total >= ReportRepository.maxSupplyPhotos)
                              ? null
                              : () => _capturePhotos(uploadedCount),
                          icon: const Icon(Icons.camera_alt),
                          label: Text(
                              total >= ReportRepository.maxSupplyPhotos
                                  ? 'Límite alcanzado'
                                  : 'Tomar fotos',
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subir pendientes.
                      if (_pending.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _uploading ? null : _uploadAll,
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
                      if (_pending.isNotEmpty) const SizedBox(height: 8),
                      // Marcar como documentado.
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (uploadedCount > 0 && !_uploading)
                                ? Colors.green.shade700
                                : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Marcar como documentado',
                              style: TextStyle(fontSize: 16)),
                          onPressed: (uploadedCount > 0 && !_uploading)
                              ? () => _markDocumented(uploadedCount)
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

/// Miniatura de una foto de insumo ya subida (URL firmada).
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