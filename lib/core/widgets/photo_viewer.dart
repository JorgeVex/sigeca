import 'dart:io';
import 'package:flutter/material.dart';

/// Muestra una foto en grande dentro de un diálogo.
/// Se cierra tocando fuera o el botón X.
/// Sirve tanto para fotos de red (URL) como locales (archivo).
class PhotoViewer {
  /// Previsualiza una foto ya subida (desde una URL firmada).
  static void showNetwork(BuildContext context, String url) {
    _show(context, Image.network(url, fit: BoxFit.contain));
  }

  /// Previsualiza una foto local (pendiente, aún no subida).
  static void showFile(BuildContext context, String path) {
    _show(context, Image.file(File(path), fit: BoxFit.contain));
  }

  static void _show(BuildContext context, Widget image) {
    showDialog(
      context: context,
      // Fondo semitransparente; tocar fuera cierra.
      barrierColor: Colors.black87,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context), // tocar fuera cierra
          child: Stack(
            children: [
              // La foto, centrada y ampliable al tamaño disponible.
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    // Absorbe el toque para que tocar la foto NO cierre,
                    // solo tocar el fondo negro cierra.
                    child: GestureDetector(
                      onTap: () {},
                      child: image,
                    ),
                  ),
                ),
              ),
              // Botón X arriba a la derecha.
              Positioned(
                top: 40,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}