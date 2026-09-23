import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/services/api_service.dart';

/// Front-camera selfie capture with the fixed event banner overlaid live in
/// the viewfinder. The final photo bakes the banner in exactly as shown.
class SelfieCameraPage extends StatefulWidget {
  const SelfieCameraPage({super.key});

  @override
  State<SelfieCameraPage> createState() => _SelfieCameraPageState();
}

class _SelfieCameraPageState extends State<SelfieCameraPage> {
  CameraController? _controller;
  Future<void>? _initFuture;
  final GlobalKey _captureKey = GlobalKey();
  final ApiService _api = ApiService();
  bool _busy = false;
  Uint8List? _preview;

  @override
  void initState() {
    super.initState();
    _initFuture = _setup();
  }

  Future<void> _setup() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(front, ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final boundary =
          _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      setState(() {
        _preview = bytes;
        _busy = false;
      });
    } catch (e) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _post() async {
    if (_preview == null || _busy) return;
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/selfie_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(_preview!);
      final res = await _api.createFeedPost(file.path);
      if (!mounted) return;
      if (res['success'] == true) {
        Navigator.pop(context, true);
      } else {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error']?.toString() ?? 'Failed to post')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, snapshot) {
            if (_controller == null || !_controller!.value.isInitialized) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            if (_preview != null) {
              return _buildPreview();
            }
            return _buildCamera();
          },
        ),
      ),
    );
  }

  Widget _buildCamera() {
    return Column(
      children: [
        Expanded(
          child: RepaintBoundary(
            key: _captureKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Image.asset(
                    'assets/Camera_banner_gemini.png',
                    fit: BoxFit.fitWidth,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
              GestureDetector(
                onTap: _busy ? null : _capture,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 28),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: Image.memory(_preview!, fit: BoxFit.contain),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _preview = null),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Retake', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _post,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text('Post', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
