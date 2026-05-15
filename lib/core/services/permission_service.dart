import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status == PermissionStatus.granted;
  }

  Future<bool> requestSMSPermission() async {
    final status = await Permission.sms.request();
    return status == PermissionStatus.granted;
  }

  Future<bool> requestPhonePermission() async {
    final status = await Permission.phone.request();
    return status == PermissionStatus.granted;
  }

  Future<bool> requestBluetoothPermissions() async {
    final advertiseStatus = await Permission.bluetoothAdvertise.request();
    final scanStatus = await Permission.bluetoothScan.request();
    return advertiseStatus == PermissionStatus.granted && scanStatus == PermissionStatus.granted;
  }

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status == PermissionStatus.granted;
  }

  Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'location': await Permission.location.isGranted,
      'sms': await Permission.sms.isGranted,
      'phone': await Permission.phone.isGranted,
      'bluetooth': await Permission.bluetoothAdvertise.isGranted && await Permission.bluetoothScan.isGranted,
      'microphone': await Permission.microphone.isGranted,
      'notification': await Permission.notification.isGranted,
    };
  }

  Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
