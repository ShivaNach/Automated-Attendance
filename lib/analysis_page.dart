import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'analysis_logic.dart';

class AnalysisPage extends StatefulWidget {
  final String imagePath;
  const AnalysisPage({super.key, required this.imagePath});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final AnalysisLogic _logic = AnalysisLogic();
  List<StudentStatus> _results = [];
  List<Face> _faces = [];
  ui.Image? _uiImage;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _processFullAnalysis();
  }

  Future<void> _processFullAnalysis() async {
    try {
      final file = File(widget.imagePath);
      if (!await file.exists()) {
        throw Exception("Image file not found at path: ${widget.imagePath}");
      }

      final data = await file.readAsBytes();
      final decoded = await decodeImageFromList(data);

      final faceDetector = FaceDetector(options: FaceDetectorOptions(enableTracking: true));
      final faces = await faceDetector.processImage(InputImage.fromFilePath(widget.imagePath));

      final results = await _logic.takeAttendance(widget.imagePath, faces);

      if (!mounted) return;

      setState(() {
        _uiImage = decoded;
        _faces = faces;
        _results = results;
        _isLoading = false;
      });

      await faceDetector.close();
    } catch (e) {
      debugPrint("Analysis Error: $e");
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.lime)),
      );
    }

    if (_errorMessage != null || _uiImage == null) {
      return Scaffold(
        body: Center(child: Text("Error: ${_errorMessage ?? 'Failed to load image'}")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Attendance Results"),
        backgroundColor: Colors.lime,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: isLandscape
          ? Row(children: [
        _buildImageSection(),
        Expanded(flex: 2, child: _buildListWithHeader())
      ])
          : Column(children: [
        _buildImageSection(),
        Expanded(flex: 3, child: _buildListWithHeader())
      ]),
    );
  }

  Widget _buildImageSection() {
    if (_uiImage == null) return const SizedBox.shrink();

    return Expanded(
      flex: 2,
      child: Align(
        alignment: Alignment.topCenter, // This removes the gap by pushing image to the top
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _uiImage!.width.toDouble(),
            height: _uiImage!.height.toDouble(),
            child: CustomPaint(painter: FacePainter(_uiImage!, _faces)),
          ),
        ),
      ),
    );
  }

  // New helper to wrap the title and the list together
  Widget _buildListWithHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20, top: 10, bottom: 5),
          child: Text(
            "Attendance List",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(child: _buildListSection()),
      ],
    );
  }

  Widget _buildListSection() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 5),
          itemCount: _results.length,
          separatorBuilder: (context, index) => const Divider(height: 0.5, color: Color(0XE0E0E0FF)),
          itemBuilder: (context, index) {
            final s = _results[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: s.isPresent ? Colors.green.shade100 : Colors.red.shade100,
                child: Icon(
                  s.isPresent ? Icons.check_circle : Icons.error_outline,
                  color: s.isPresent ? Colors.green : Colors.red,
                ),
              ),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text("Roll: ${s.rollNo}"),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: s.isPresent ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s.isPresent ? "PRESENT" : "ABSENT",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final ui.Image image;
  final List<Face> faces;
  FacePainter(this.image, this.faces);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..color = Colors.lime;

    for (var face in faces) {
      canvas.drawRect(face.boundingBox, paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter old) => image != old.image || faces != old.faces;
}