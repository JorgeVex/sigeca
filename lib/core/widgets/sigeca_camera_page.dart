import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Pantalla de cámara embebida en modo ráfaga.
/// Incluye zoom, flash y temporizador.
/// Devuelve la lista de XFile tomadas al cerrar.
class SigecaCameraPage extends StatefulWidget {
  /// Cuántas fotos más se pueden tomar (límite restante).
  final int remaining;

  const SigecaCameraPage({super.key, required this.remaining});

  @override
  State<SigecaCameraPage> createState() => _SigecaCameraPageState();
}

class _SigecaCameraPageState extends State<SigecaCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;

  final List<XFile> _taken = [];
  bool _capturing = false;
  String? _error;

  // --- Zoom ---
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0; // zoom al iniciar el gesto de pellizco

  // --- Flash ---
  FlashMode _flashMode = FlashMode.off;

  // --- Temporizador ---
  int _timerSeconds = 0; // 0 = off
  int _countdown = 0; // cuenta regresiva en curso
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No se encontró ninguna cámara.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      // Rango de zoom soportado por el dispositivo.
      final minZ = await controller.getMinZoomLevel();
      final maxZ = await controller.getMaxZoomLevel();

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _minZoom = minZ;
        _maxZoom = maxZ;
        _currentZoom = minZ;
      });

      await controller.setFlashMode(_flashMode);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al abrir la cámara: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // --- Zoom con pellizco ---
  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    final controller = _controller;
    if (controller == null) return;

    // details.scale: 1.0 = sin cambio; >1 acerca, <1 aleja.
    double newZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    if (newZoom == _currentZoom) return;

    setState(() => _currentZoom = newZoom);
    await controller.setZoomLevel(newZoom);
  }

  // --- Zoom con slider ---
  Future<void> _setZoom(double value) async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _currentZoom = value);
    await controller.setZoomLevel(value);
  }

  // --- Flash ---
  Future<void> _cycleFlash() async {
    final controller = _controller;
    if (controller == null) return;

    // Alternar: off -> auto -> always (torch) -> off
    FlashMode next;
    if (_flashMode == FlashMode.off) {
      next = FlashMode.auto;
    } else if (_flashMode == FlashMode.auto) {
      next = FlashMode.always;
    } else {
      next = FlashMode.off;
    }

    setState(() => _flashMode = next);
    await controller.setFlashMode(next);
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      default:
        return Icons.flash_on;
    }
  }

  // --- Temporizador ---
  void _cycleTimer() {
    setState(() {
      // off -> 3 -> 5 -> 10 -> off
      if (_timerSeconds == 0) {
        _timerSeconds = 3;
      } else if (_timerSeconds == 3) {
        _timerSeconds = 5;
      } else if (_timerSeconds == 5) {
        _timerSeconds = 10;
      } else {
        _timerSeconds = 0;
      }
    });
  }

  // --- Captura ---
  Future<void> _onShutterPressed() async {
    if (_capturing || _countdown > 0) return;

    if (_taken.length >= widget.remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Límite alcanzado (${widget.remaining}).')),
      );
      return;
    }

    // Si hay temporizador, cuenta regresiva antes de disparar.
    if (_timerSeconds > 0) {
      setState(() => _countdown = _timerSeconds);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_countdown <= 1) {
          t.cancel();
          setState(() => _countdown = 0);
          _takePhoto();
        } else {
          setState(() => _countdown--);
        }
      });
    } else {
      _takePhoto();
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_capturing) return;

    setState(() => _capturing = true);
    try {
      final photo = await controller.takePicture();
      setState(() => _taken.add(photo));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _removeTaken(int index) {
    setState(() => _taken.removeAt(index));
  }

  void _finish() {
    _timer?.cancel();
    Navigator.pop(context, _taken);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final limitReached = _taken.length >= widget.remaining;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Cámara (${_taken.length}/${widget.remaining})'),
        actions: [
          // Flash.
          IconButton(
            icon: Icon(_flashIcon, color: Colors.white),
            onPressed: _controller == null ? null : _cycleFlash,
          ),
          // Temporizador.
          IconButton(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: Colors.white),
                if (_timerSeconds > 0)
                  Text('$_timerSeconds',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
              ],
            ),
            onPressed: _controller == null ? null : _cycleTimer,
          ),
          TextButton(
            onPressed: _finish,
            child: Text('Listo (${_taken.length})',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center),
              ),
            )
          : _controller == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // --- Preview con zoom por pellizco ---
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            onScaleStart: _onScaleStart,
                            onScaleUpdate: _onScaleUpdate,
                            child: Center(child: CameraPreview(_controller!)),
                          ),

                          // Cuenta regresiva del temporizador.
                          if (_countdown > 0)
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text('$_countdown',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold)),
                            ),

                          // Slider de zoom (si el dispositivo lo soporta).
                          if (_maxZoom > _minZoom)
                            Positioned(
                              right: 8,
                              top: 20,
                              bottom: 20,
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: SizedBox(
                                  width: 200,
                                  child: Slider(
                                    min: _minZoom,
                                    max: _maxZoom,
                                    value: _currentZoom,
                                    activeColor: Colors.white,
                                    onChanged: _setZoom,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // --- Tira de miniaturas ---
                    if (_taken.isNotEmpty)
                      Container(
                        height: 80,
                        color: Colors.black,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          itemCount: _taken.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.file(
                                      File(_taken[index].path),
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () => _removeTaken(index),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    // --- Botón disparar (con safe area abajo) ---
                    Container(
                      color: Colors.black,
                      padding: EdgeInsets.only(
                        top: 16,
                        // Sube el botón si el dispositivo tiene barra de
                        // navegación inferior (gestos/botones).
                        bottom: 16 + bottomInset,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: (_capturing || limitReached || _countdown > 0)
                                ? null
                                : _onShutterPressed,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: limitReached
                                    ? Colors.grey
                                    : Colors.white,
                                border: Border.all(
                                    color: Colors.white, width: 4),
                              ),
                              child: _capturing
                                  ? const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(
                                          color: Colors.black,
                                          strokeWidth: 3),
                                    )
                                  : const Icon(Icons.camera_alt,
                                      color: Colors.black, size: 32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}