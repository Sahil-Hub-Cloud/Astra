import '../../sos_service.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import '../utils/shared_queue_storage.dart';

class OfflineQueueManager {
  Future<void> addToOfflineQueue({
    required String message,
    required List<String> recipients,
    required double latitude,
    required double longitude,
    required String timestamp,
  }) async {
    final queue = await SharedQueueStorage.loadQueue();

    for (final recipient in recipients) {
      final cleanNumber = recipient.replaceAll(RegExp(r'[^0-9+]'), '');
      if (cleanNumber.isNotEmpty) {
        final emergencyData = {
          'message': message,
          'phoneNumber': cleanNumber,
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': timestamp,
          'type': 'emergency_alert',
        };
        queue.add(emergencyData);
      }
    }
    
    await SharedQueueStorage.saveQueue(queue);
    print('✅ Added ${recipients.length} SMS entries to offline queue. Total: ${queue.length}');
    
    await _triggerWorkManager();
  }
  
  Future<void> _triggerWorkManager() async {
    try {
      const MethodChannel _channel = MethodChannel('astra/offline_queue');
      await _channel.invokeMethod('scheduleOfflineProcessing');
      print('✅ WorkManager scheduled for offline queue processing');
    } catch (e) {
      print('⚠️ Could not trigger WorkManager, falling back to app-open processing: $e');
    }
  }
  
  Future<void> processOfflineQueue() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return;
    }
    
    final queue = await SharedQueueStorage.loadQueue();
    
    if (queue.isEmpty) {
      return;
    }
    
    print('🔄 Processing offline queue: ${queue.length} items');
    
    final successfulSends = <int>[];
    
    for (int i = 0; i < queue.length; i++) {
      final item = queue[i];
      final success = await _sendQueuedItem(item);
      
      if (success) {
        successfulSends.add(i);
        print('✅ Successfully sent queued item ${i + 1}');
      } else {
        print('❌ Failed to send queued item ${i + 1}');
      }
    }
    
    if (successfulSends.isNotEmpty) {
      final remainingQueue = queue.whereIndexed((index, element) => !successfulSends.contains(index)).toList();
      await SharedQueueStorage.saveQueue(remainingQueue);
      print('✅ Processed ${successfulSends.length} items, ${remainingQueue.length} remaining');
    }
    
    if (await SharedQueueStorage.getQueueSize() > 0) {
      await _triggerWorkManager();
    }
  }
  
  Future<bool> _sendQueuedItem(Map<String, dynamic> item) async {
    try {
      final message = item['message'] as String;
      final phoneNumber = item['phoneNumber'] as String;
      
      final sosService = SosService();
      await sosService.sendSmsToSingleContact(phoneNumber, message);
      return true;
    } catch (e) {
      print('Failed to send queued item: $e');
      return false;
    }
  }
  
  Future<List<Map<String, dynamic>>> getQueue() async {
    return await SharedQueueStorage.loadQueue();
  }
  
  Future<void> clearQueue() async {
    await SharedQueueStorage.clearQueue();
  }
  
  Future<int> getQueueSize() async {
    return await SharedQueueStorage.getQueueSize();
  }
  
  Future<bool> queueExists() async {
    return await SharedQueueStorage.queueExists();
  }
}
