import 'package:geolocator/geolocator.dart';

class LocationHelper {
  /// ขอ permission + คืนตำแหน่งปัจจุบัน ถ้าไม่ได้ให้ throw
  static Future<Position> getCurrentPositionOrThrow() async {
    final ok = await _ensurePermission();
    if (!ok) {
      throw Exception('กรุณาอนุญาตการเข้าถึงตำแหน่งที่ตั้ง');
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return false;
    }
    if (perm == LocationPermission.deniedForever) return false;
    return true;
  }
}
