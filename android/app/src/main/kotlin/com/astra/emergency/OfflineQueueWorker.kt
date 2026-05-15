package com.astra.emergency

import android.content.Context
import android.telephony.SmsManager
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class OfflineQueueWorker(appContext: Context, workerParams: WorkerParameters) : Worker(appContext, workerParams) {

    override fun doWork(): Result {
        return try {
            Log.d("OfflineQueueWorker", "Processing offline queue...")
            
            // Get the queue file from the same location as Dart (app documents directory)
            // Flutter's applicationDocumentsDirectory on Android is "app_flutter"
            val flutterDir = File(applicationContext.filesDir.parent, "app_flutter")
            val queueFile = File(flutterDir, "offline_queue.json")
            val lockFile = File(flutterDir, "offline_queue.lock")
            
            if (queueFile.exists()) {
                // Wait for up to 3 seconds if file is locked
                var waitCount = 0
                while (lockFile.exists() && waitCount < 30) {
                    Thread.sleep(100)
                    waitCount++
                }
                
                val jsonString = queueFile.readText()
                if (jsonString.isNotEmpty()) {
                    val jsonArray = JSONArray(jsonString)
                    val remainingItems = JSONArray()
                    var successCount = 0
                    
                    Log.d("OfflineQueueWorker", "Processing ${jsonArray.length()} items atomically")
                    
                    for (i in 0 until jsonArray.length()) {
                        val item = jsonArray.getJSONObject(i)
                        try {
                            val phoneNumber = item.getString("phoneNumber")
                            val message = item.getString("message")
                            
                            sendSms(phoneNumber, message)
                            successCount++
                        } catch (e: Exception) {
                            Log.e("OfflineQueueWorker", "Failed to send item $i, keeping in queue", e)
                            remainingItems.put(item)
                        }
                    }
                    
                    // Update the file with remaining items or delete if empty
                    if (remainingItems.length() > 0) {
                        try {
                            lockFile.createNewFile()
                            queueFile.writeText(remainingItems.toString())
                            Log.d("OfflineQueueWorker", "Updated queue: $successCount sent, ${remainingItems.length()} remaining")
                        } finally {
                            lockFile.delete()
                        }
                    } else {
                        queueFile.delete()
                        Log.d("OfflineQueueWorker", "All items processed successfully. Queue file deleted.")
                    }
                }
            } else {
                Log.d("OfflineQueueWorker", "No queue file found at ${queueFile.absolutePath}")
            }
            
            Result.success()
        } catch (e: Exception) {
            Log.e("OfflineQueueWorker", "Fatal error in worker: ${e.message}", e)
            Result.retry()
        }
    }
    
    private fun sendSms(phoneNumber: String, message: String) {
        try {
            val smsManager: SmsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                applicationContext.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            
            smsManager.sendTextMessage(phoneNumber, null, message, null, null)
            Log.d("OfflineQueueWorker", "SMS sent successfully to $phoneNumber")
        } catch (e: Exception) {
            Log.e("OfflineQueueWorker", "Failed to send SMS to $phoneNumber: ${e.message}")
            throw e
        }
    }
    
    companion object {
        private const val QUEUE_WORK_NAME = "offline_queue_processing"
        
        fun scheduleQueueProcessing(context: Context) {
            Log.d("OfflineQueueWorker", "Scheduling offline queue processing via WorkManager")
            
            val constraints = androidx.work.Constraints.Builder()
                .setRequiredNetworkType(androidx.work.NetworkType.CONNECTED)
                .build()
                
            val workRequest = androidx.work.OneTimeWorkRequest.Builder(OfflineQueueWorker::class.java)
                .setConstraints(constraints)
                .addTag(QUEUE_WORK_NAME)
                .build()
                
            androidx.work.WorkManager.getInstance(context)
                .enqueueUniqueWork(
                    QUEUE_WORK_NAME,
                    androidx.work.ExistingWorkPolicy.REPLACE,
                    workRequest
                )
        }
    }
}