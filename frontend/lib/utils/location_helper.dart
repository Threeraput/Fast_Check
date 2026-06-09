import 'package:geolocator/geolocator.dart';

class MockLocationDetectedException implements Exception {
  final String message;
  const MockLocationDetectedException([
    this.message =
        'ตรวจพบการใช้ตำแหน่งจำลอง (Fake GPS/Mock Location) ระบบไม่อนุญาตให้ใช้งาน',
  ]);

  @override
  String toString() => message;
}

class LocationHelper {
  /// ขอ permission + คืนตำแหน่งปัจจุบัน ถ้าไม่ได้ให้ throw
  ///
  /// [blockMockedLocation] ใช้บล็อกการส่งพิกัดจาก mock/fake GPS ที่ฝั่ง client
  static Future<Position> getCurrentPositionOrThrow({
    bool blockMockedLocation = true,
  }) async {
    final ok = await _ensurePermission();
    if (!ok) {
      throw Exception('กรุณาอนุญาตการเข้าถึงตำแหน่งที่ตั้ง');
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    if (blockMockedLocation && position.isMocked) {
      throw const MockLocationDetectedException(
        'ตรวจพบการใช้ตำแหน่งจำลอง (Fake GPS/Mock Location) ระบบไม่อนุญาตให้เช็คชื่อ',
      );
    }

    return position;
  }

  static bool isMockLocationError(Object error) {
    return error is MockLocationDetectedException;
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
