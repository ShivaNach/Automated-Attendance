import 'package:camera/camera.dart';
import 'package:automated_attendance/analysis_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late List<CameraDescription> cameras;
  CameraController? controller;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _startMode();
  }

  // Set up orientation and camera
  Future<void> _startMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    await initializeCamera();
  }

  Future<void> _stopMode() async {
    await SystemChrome.setPreferredOrientations([]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (controller != null) {
      await controller!.dispose();
      controller = null;
      setState(() => _isCameraInitialized = false);
    }
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await controller!.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  @override
  void dispose() {
    _stopMode();
    super.dispose();
  }

  Future<void> _goToAnalysis(String path) async {
    await _stopMode();

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AnalysisPage(imagePath: path)),
    );
    _startMode();
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      _goToAnalysis(photo.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.lime)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: CameraPreview(controller!)
          ),
          // Gallery Button
          Positioned(
            bottom: 30,
            left: 30, // Added left positioning
            child: IconButton(
              icon: const Icon(Icons.photo_library, color: Colors.lime, size: 48),
              onPressed: _pickImageFromGallery,
            ),
          ),
          // Shutter Button
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 40),
              child: GestureDetector(
                onTap: () async {
                  try {
                    final XFile photo = await controller!.takePicture();
                    _goToAnalysis(photo.path);
                  } catch (e) {
                    debugPrint(e.toString());
                  }
                },
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 5)
                  ),
                  child: const Center(
                    child: Icon(Icons.camera_alt, color: Colors.lime, size: 48),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}