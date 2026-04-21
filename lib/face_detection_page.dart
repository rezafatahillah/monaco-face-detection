import 'dart:async';
import 'dart:typed_data';
// import 'dart:ui' as ui; // dart:ui tidak lagi diperlukan untuk takePicture
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart'; // Rendering tidak lagi diperlukan
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'api_service.dart';

class FaceDetectionPage extends StatefulWidget {
  const FaceDetectionPage({super.key});

  @override
  _FaceDetectionPageState createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  // GlobalKey masih dipertahankan agar kode tidak rusak, walau tidak dipakai untuk capture
  final GlobalKey _globalKey = GlobalKey(); 
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableTracking: false,
    ),
  );
  
  final ApiService _apiService = ApiService();
  bool _isProcessing = false;
  bool _isCapturingEffect = false;
  bool _isUploading = false;
  String _uploadStatus = "";
  Face? _detectedFace;
  Size? _cameraSize;
  DateTime? _lastDetectedTime;
  Timer? _captureTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _startCamera();
  }

  Future<void> _startCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[1], 
      ResolutionPreset.low, 
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    
    await _controller!.initialize();
    if (!mounted) return;
    
    _cameraSize = Size(
      _controller!.value.previewSize!.height, 
      _controller!.value.previewSize!.width
    );
    
    _controller!.startImageStream((image) {
      if (!_isProcessing && !_isUploading) _processCamera(image);
    });
    setState(() {});
  }

  Future<void> _processCamera(CameraImage image) async {
    _isProcessing = true;
    try {
      final allBytes = Uint8List(image.planes.fold(0, (sum, plane) => sum + plane.bytes.length));
      int offset = 0;
      for (final plane in image.planes) {
        allBytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
        offset += plane.bytes.length;
      }

      final inputImage = InputImage.fromBytes(
        bytes: allBytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);
      
      if (mounted) {
        setState(() {
          if (faces.isNotEmpty) {
            _detectedFace = faces.first;
            _lastDetectedTime = DateTime.now();
            
            _captureTimer ??= Timer(const Duration(seconds: 1), () {
              _triggerCaptureEffect();
            });
          } else {
            if (_lastDetectedTime != null && 
                DateTime.now().difference(_lastDetectedTime!).inMilliseconds > 150) {
              _detectedFace = null;
              _captureTimer?.cancel();
              _captureTimer = null;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Process Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _triggerCaptureEffect() async {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) return;
    
    setState(() {
      _isCapturingEffect = true;
      _isUploading = true;
      _uploadStatus = "MENCOCOKKAN WAJAH...";
    });
    
    try {
      // Perubahan Utama: Menggunakan takePicture() untuk gambar bersih
      // takePicture otomatis mengambil gambar mentah dari sensor, tanpa overlay Flutter.
      final XFile capturedImage = await _controller!.takePicture();
      final Uint8List imageBytes = await capturedImage.readAsBytes();

      // Gambar ini sudah bersih (tanpa kotak hijau & banner) dan ukuran filenya 
      // harusnya sudah disesuaikan oleh takePicture() agar tidak terlalu besar (tergantung ResolutionPreset).

      bool success = await _apiService.uploadFaceImage(imageBytes);
      
      if (mounted) {
        setState(() {
          _uploadStatus = success ? "UPLOAD BERHASIL!" : "UPLOAD GAGAL!";
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _uploadStatus = "");
        });
      }
    } catch (e) {
      debugPrint("Capture Error: $e");
      if (mounted) {
        setState(() {
          _uploadStatus = "CAPTURE GAGAL!";
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _uploadStatus = "");
        });
      }
    }

    setState(() => _isUploading = false);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _isCapturingEffect = false);
    });
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _controller?.stopImageStream();
    _controller?.dispose();
    _faceDetector.close();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    return Scaffold(
      body: RepaintBoundary( // Masih dipertahankan agar struktur tidak berubah, walau tidak dipakai capture
        key: _globalKey,
        child: Stack(
          children: [
            Positioned.fill(child: CameraPreview(_controller!)),
            
            if (_cameraSize != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: FacePainter(_detectedFace, _cameraSize!),
                ),
              ),

            if (_isCapturingEffect)
              Container(color: Colors.white.withOpacity(0.8)),

            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                color: _uploadStatus.isNotEmpty 
                    ? (_uploadStatus == "UPLOAD BERHASIL!" ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8))
                    : (_detectedFace != null ? Colors.blue.withOpacity(0.7) : Colors.black.withOpacity(0.5)),
                child: Text(
                  _uploadStatus.isNotEmpty 
                      ? _uploadStatus 
                      : (_detectedFace != null ? "WAJAH TERDETEKSI" : "MENCARI WAJAH..."),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final Face? face;
  final Size cameraSize;
  FacePainter(this.face, this.cameraSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (face == null) return;
    
    final double scaleX = size.width / cameraSize.width;
    final double scaleY = size.height / cameraSize.height;

    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    
    final rect = face!.boundingBox;

    final double left = (cameraSize.width - rect.right) * scaleX;
    final double right = (cameraSize.width - rect.left) * scaleX;
    final double top = rect.top * scaleY;
    final double bottom = rect.bottom * scaleY;

    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) => true;
}