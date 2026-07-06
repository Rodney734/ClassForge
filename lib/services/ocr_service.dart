import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  // Extract text from image
  Future<List<String>> extractStudentIdsFromImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      // Extract all text from image
      final fullText = recognizedText.text;

      // Parse student IDs (looking for patterns like: 2024-001, STU001, etc.)
      final studentIds = _parseStudentIds(fullText);

      return studentIds;
    } catch (e) {
      print('OCR Error: $e');
      return [];
    }
  }

  // Parse student IDs from extracted text
  List<String> _parseStudentIds(String text) {
    final RegExp idPattern = RegExp(
      r'\b\d{4}-\d{3}\b|\bSTU\d{3}\b|\b[0-9]{6,10}\b',
    );
    final matches = idPattern.allMatches(text);

    final ids = matches.map((match) => match.group(0)!).toSet().toList();
    return ids;
  }

  // Dispose the recognizer
  void dispose() {
    _textRecognizer.close();
  }
}
