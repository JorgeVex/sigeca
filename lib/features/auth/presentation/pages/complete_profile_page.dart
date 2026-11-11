import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_providers.dart';
import '../../../assignments/presentation/providers/report_providers.dart';
/// Pantalla que el usuario completa en su primer inicio de sesión:
/// ingresa su cédula y dibuja su firma. Obligatoria para usar la app.
class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  final _documentController = TextEditingController();

  // Controlador del lienzo de firma.
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _saving = false;

  @override
  void dispose() {
    _documentController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final cedula = _documentController.text.trim();

    // Validaciones.
    if (cedula.isEmpty) {
      _showError('Ingresa tu número de documento.');
      return;
    }
    if (_signatureController.isEmpty) {
      _showError('Dibuja tu firma antes de continuar.');
      return;
    }

    setState(() => _saving = true);

    try {
      // 1. Exportar la firma dibujada a bytes PNG.
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes == null) {
        throw Exception('No se pudo procesar la firma.');
      }

      // 2. Guardar los bytes en un archivo temporal para subirlo.
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/firma_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(signatureBytes);

      // 3. Obtener el id del usuario autenticado.
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // 4. Subir la firma a Storage.
      final storage = ref.read(storageServiceProvider);
      final signatureUrl = await storage.uploadSignature(
        photo: XFile(file.path),
        userId: userId,
      );

      // 5. Guardar cédula + ruta de firma en el perfil.
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.completeProfile(
        userId: userId,
        documentId: cedula,
        signatureUrl: signatureUrl,
      );

      // 6. Refrescar el perfil para que el router deje pasar.
      ref.invalidate(currentProfileProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Error: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completa tu perfil'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // sin botón de volver
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Antes de continuar, necesitamos tu documento de identidad y tu '
              'firma. Se usarán para suscribir tus reportes.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // --- Cédula ---
            const Text('Número de documento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _documentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Ej: 1075123456',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 24),

            // --- Firma ---
            const Text('Tu firma',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Dibuja tu firma en el recuadro con el dedo.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Signature(
                controller: _signatureController,
                height: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _signatureController.clear(),
                icon: const Icon(Icons.refresh, color: Colors.teal),
                label: const Text('Limpiar firma',
                    style: TextStyle(color: Colors.teal)),
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
                    : const Text('Guardar y continuar',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}