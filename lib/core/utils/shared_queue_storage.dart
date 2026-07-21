import "package:flutter/foundation.dart";
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class SharedQueueStorage {
  static const String _queueFileName = 'offline_queue.json';
  
  static Future<String> getStorageDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<String> getQueueFilePath() async {
    final directory = await getStorageDirectory();
    return '$directory/$_queueFileName';
  }
  
  static Future<String> getLockFilePath() async {
    final directory = await getStorageDirectory();
    return '$directory/offline_queue.lock';
  }

  static Future<void> _waitForLock() async {
    final lockFile = File(await getLockFilePath());
    int retries = 0;
    while (await lockFile.exists() && retries < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }
  }

  static Future<void> saveQueue(List<Map<String, dynamic>> queueData) async {
    final lockFile = File(await getLockFilePath());
    try {
      await _waitForLock();
      await lockFile.create();

      final filePath = await getQueueFilePath();
      final file = File(filePath);
      final tmpFile = File('$filePath.tmp');
      
      final jsonString = jsonEncode(queueData);
      await tmpFile.writeAsString(jsonString);
      await tmpFile.rename(filePath);
      
      debugPrint('✅ Queue saved atomically: ${queueData.length} items');
    } catch (e) {
      debugPrint('❌ Error saving queue: $e');
      rethrow;
    } finally {
      if (await lockFile.exists()) await lockFile.delete();
    }
  }
  
  static Future<List<Map<String, dynamic>>> loadQueue() async {
    try {
      await _waitForLock();
      final filePath = await getQueueFilePath();
      final file = File(filePath);
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        if (jsonString.isNotEmpty) {
          final decoded = jsonDecode(jsonString);
          if (decoded is List) {
            return decoded.cast<Map<String, dynamic>>();
          }
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('❌ Error loading queue: $e');
      return [];
    }
  }
  
  static Future<void> clearQueue() async {
    try {
      final filePath = await getQueueFilePath();
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ Queue file cleared');
      }
    } catch (e) {
      debugPrint('❌ Error clearing queue: $e');
    }
  }
  
  static Future<int> getQueueSize() async {
    final queue = await loadQueue();
    return queue.length;
  }
  
  static Future<bool> queueExists() async {
    try {
      final filePath = await getQueueFilePath();
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}
