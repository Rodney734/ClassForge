import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  static final FileStorageService _instance = FileStorageService._internal();
  factory FileStorageService() => _instance;
  FileStorageService._internal();

  Future<Directory> _getChatDocumentsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final chatDir = Directory('${appDir.path}/chat_documents');
    if (!await chatDir.exists()) {
      await chatDir.create(recursive: true);
    }
    return chatDir;
  }

  // Save file locally
  Future<String> saveFileLocally(File file, String fileName) async {
    final chatDir = await _getChatDocumentsDirectory();
    final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final savedFile = File('${chatDir.path}/$uniqueFileName');
    await file.copy(savedFile.path);
    return savedFile.path;
  }

  // Save file from bytes
  Future<String> saveFileFromBytes(List<int> bytes, String fileName) async {
    final chatDir = await _getChatDocumentsDirectory();
    final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final savedFile = File('${chatDir.path}/$uniqueFileName');
    await savedFile.writeAsBytes(bytes);
    return savedFile.path;
  }

  // Get file
  Future<File?> getFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  // Delete file
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print("Error deleting file: $e");
      return false;
    }
  }

  // Get all files in chat directory
  Future<List<File>> getAllFiles() async {
    final chatDir = await _getChatDocumentsDirectory();
    final files = await chatDir.list().toList();
    return files.whereType<File>().toList();
  }

  // Get file size
  Future<String> getFileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      final bytes = await file.length();
      if (bytes < 1024) {
        return '$bytes B';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }
    return 'Unknown';
  }
}
