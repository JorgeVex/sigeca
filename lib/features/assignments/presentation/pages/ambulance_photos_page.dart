import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/report_model.dart';
import '../../data/repositories/report_repository.dart';
import '../providers/report_providers.dart';
import '../../../../core/services/watermark_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/widgets/photo_viewer.dart';
import '../../../../core/widgets/sigeca_camera_page.dart';

/// Pantalla de captura de fotos de aseo de una ambulancia.
class AmbulancePhotosPage extends ConsumerStatefulWidget {
  final ReportModel report;
  final ReportAmbulancePhotos ambGroup;

  const AmbulancePhotosPage({
    super.key,
    required this.report,
    required this.ambGroup,
  });

  @override
  ConsumerState<AmbulancePhotosPage> createState() =>
      _AmbulancePhotosPageState();
}

class _AmbulancePhotosPageState extends ConsumerState<AmbulancePhotosPage> {
  final WatermarkService _watermarkService = WatermarkService();

  final List<XFile> _pending = [];
  bool _uploading = false;

  Future<void> _capturePhotos(int uploadedCount) async {
    final total = uploadedCount + _pending.length;
    final remaining = ReportRepository.maxPhotosPerAmbulance - total;

    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Límite alcanzado (${ReportRepository.maxPhotosPerAmbulance}). '
                'Borra una para tomar otra.')),
      );
      return;
    }

    final result = await Navigator.push<List<XFile>>(
      context,
      MaterialPageRoute(
        builder: (_) => SigecaCameraPage(remaining: remaining),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _pending.addAll(result));
    }
  }

  void _removePending(int index) {
    setState(() => _pending.removeAt(index));
  }

  Future<void> _uploadAll(int uploadedCount) async {
    if (_pending.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final profile = ref.read(currentProfileProvider).value;
      final auxiliarName = profile?.fullName ?? 'Auxiliar';

      final sealedFutures = _pending.map((photo) {
        return _watermarkService.applyWatermark(
          photo: photo,
          auxiliarName: auxiliarName,
          label: 'Ambulancia ${widget.ambGroup.plate}',
        );
      }).toList();

      final sealed = await Future.wait(sealedFutures);

      final repo = ref.read(reportRepositoryProvider);
      await repo.addAmbulancePhotosBatch(
        photos: sealed,
        reportId: widget.report.id,
        ambGroupId: widget.ambGroup.id,
        ambulanceId: widget.ambGroup.ambulanceId,
      );

      if (mounted) {
        setState(() => _pending.clear());
        ref.invalidate(ambulancePhotosProvider(widget.ambGroup.id));
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

  Future<void> _deleteUploaded(ReportPhoto photo) async {
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
      await repo.removeAmbulancePhoto(
        photoId: photo.id,
        photoPath: photo.photoUrl,
        ambGroupId: widget.ambGroup.id,
      );
      ref.invalidate(ambulancePhotosProvider(widget.ambGroup.id));
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
    final photosAsync = ref.watch(ambulancePhotosProvider(widget.ambGroup.id));
    final storageService = ref.watch(storageServiceProvider);
    final canEdit = !widget.report.isCompleted;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ambulancia ${widget.ambGroup.plate}'),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: uploadedCount >= ReportRepository.minPhotosPerAmbulance
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                child: Text(
                  '$uploadedCount subidas'
                  '${_pending.isNotEmpty ? ' + ${_pending.length} pendientes' : ''}'
                  ' (de ${ReportRepository.minPhotosPerAmbulance}-${ReportRepository.maxPhotosPerAmbulance})'
                  '${uploadedCount >= ReportRepository.minPhotosPerAmbulance ? ' — mínimo ✓' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
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
                          return _AmbThumbnail(
                            photo: photo,
                            storageService: storageService,
                            canDelete: canEdit && !_uploading,
                            onDelete: () => _deleteUploaded(photo),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
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
                          return _PendingAmbThumbnail(
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
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: (_uploading ||
                                  total >=
                                      ReportRepository.maxPhotosPerAmbulance)
                              ? null
                              : () => _capturePhotos(uploadedCount),
                          icon: const Icon(Icons.camera_alt),
                          label: Text(
                              total >= ReportRepository.maxPhotosPerAmbulance
                                  ? 'Límite alcanzado'
                                  : 'Tomar fotos',
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 8),
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

/// Miniatura de foto de ambulancia ya subida.
class _AmbThumbnail extends StatelessWidget {
  final ReportPhoto photo;
  final dynamic storageService;
  final bool canDelete;
  final VoidCallback onDelete;

  const _AmbThumbnail({
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
            GestureDetector(
              onTap: () => PhotoViewer.showNetwork(context, snapshot.data!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(snapshot.data!, fit: BoxFit.cover),
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

/// Miniatura de foto pendiente de ambulancia.
class _PendingAmbThumbnail extends StatelessWidget {
  final XFile file;
  final bool canDelete;
  final VoidCallback onDelete;

  const _PendingAmbThumbnail({
    required this.file,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () => PhotoViewer.showFile(context, file.path),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(file.path), fit: BoxFit.cover),
          ),
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