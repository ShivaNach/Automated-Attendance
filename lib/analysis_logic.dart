import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class StudentStatus {
  final String name;
  final String rollNo;
  final double confidence;
  bool isPresent;

  StudentStatus({
    required this.name,
    required this.rollNo,
    required this.confidence,
    this.isPresent = false,
  });
}

class AnalysisLogic {
  Interpreter? _interpreter;
  Map<String, dynamic>? _metadata;
  // Cache embeddings to avoid re-processing images every time
  final Map<String, List<double>> _embeddingCache = {};

  Future<void> init() async {
    _interpreter = await Interpreter.fromAsset('assets/model/facenet.tflite');
    final String response = await rootBundle.loadString('assets/metadata.json');
    _metadata = json.decode(response);
  }

  Future<List<StudentStatus>> takeAttendance(String imagePath, List<Face> detectedFaces) async {
    if (_interpreter == null || _metadata == null) await init();

    final bytes = await File(imagePath).readAsBytes();
    img.Image? fullImage = img.decodeImage(bytes);
    if (fullImage == null) throw Exception("Could not decode image");

    // 1. Process detected faces from the camera shot
    List<List<double>> detectedEmbeddings = [];
    for (var face in detectedFaces) {
      img.Image crop = img.copyCrop(fullImage,
          x: face.boundingBox.left.toInt(),
          y: face.boundingBox.top.toInt(),
          width: face.boundingBox.width.toInt(),
          height: face.boundingBox.height.toInt()
      );
      detectedEmbeddings.add(_getEmbedding(img.copyResize(crop, width: 160, height: 160)));
    }

    fullImage = null; //clear the buffer

    List<StudentStatus> attendanceList = [];
    List students = _metadata!['students'];

    // 2. Efficiently process students
    for (var student in students) {
      String studentId = student['roll_no'];
      List<double> refEmbedding;

      // Check cache first to avoid loading assets repeatedly
      if (_embeddingCache.containsKey(studentId)) {
        refEmbedding = _embeddingCache[studentId]!;
      } else {
        final refData = await rootBundle.load('assets/photos/${student['ref_image']}');
        final img.Image? refImg = img.decodeImage(refData.buffer.asUint8List());
        if (refImg == null) continue;

        refEmbedding = _getEmbedding(img.copyResize(refImg, width: 160, height: 160));
        _embeddingCache[studentId] = refEmbedding;
      }

      double maxSim = 0.0;
      for (var emb in detectedEmbeddings) {
        double sim = _cosineSimilarity(refEmbedding, emb);
        if (sim > maxSim) maxSim = sim;
      }

      attendanceList.add(StudentStatus(
        name: student['name'],
        rollNo: student['roll_no'],
        confidence: maxSim,
      ));
    }

    // 3. Logic for Presence
    attendanceList.sort((a, b) => b.confidence.compareTo(a.confidence));
    int faceCount = detectedFaces.length;
    for (int i = 0; i < attendanceList.length; i++) {
      attendanceList[i].isPresent = i < faceCount && attendanceList[i].confidence > 0.58;
      // Added a threshold (0.58) so you don't mark people present if they don't look like the face
    }


    // Clearing the cache to avoid wastage of space
    try {
      if (await File(imagePath).exists() && imagePath.contains('cache')) {
        await File(imagePath).delete();
        debugPrint("Storage Cleared: Original photo deleted.");
      }
    } catch (e) {
      debugPrint("Cleanup failed: $e");
    }
    return attendanceList;
  }

  List<double> _getEmbedding(img.Image image) {
    var input = _imageToByteListFloat32(image).reshape([1, 160, 160, 3]);
    var output = List.generate(1, (index) => List<double>.filled(512, 0.0));
    _interpreter!.run(input, output);
    return List<double>.from(output[0]);
  }

  Float32List _imageToByteListFloat32(img.Image image) {
    var buffer = Float32List(1 * 160 * 160 * 3);
    int i = 0;
    for (var y = 0; y < 160; y++) {
      for (var x = 0; x < 160; x++) {
        var pixel = image.getPixel(x, y);
        // Normalize 0-255 to -1 to 1 (Typical for FaceNet)
        buffer[i++] = (pixel.r - 127.5) / 128.0;
        buffer[i++] = (pixel.g - 127.5) / 128.0;
        buffer[i++] = (pixel.b - 127.5) / 128.0;
      }
    }
    return buffer;
  }

  double _cosineSimilarity(List<double> e1, List<double> e2) {
    double dot = 0.0, n1 = 0.0, n2 = 0.0;
    for (int i = 0; i < 128; i++) {
      dot += e1[i] * e2[i];
      n1 += e1[i] * e1[i];
      n2 += e2[i] * e2[i];
    }
    return dot / (math.sqrt(n1) * math.sqrt(n2));
  }
}