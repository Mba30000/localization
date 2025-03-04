import 'package:wifi_scan/wifi_scan.dart';
import 'dart:math' as math;
import 'package:indoornav/GridLocation.dart';
import 'package:indoornav/DatabaseHelper.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';

class WiFiAnalyser {
  static Future<GridLocation?> estimatePosition(double threshold) async {
    if (!Platform.isAndroid) return null;

    Map<WiFiAccessPoint, GridLocation> topAPs = {};
    List<WiFiAccessPoint> results = await WiFiScan.instance.getScannedResults();
     results = results.where((ap) => ap.ssid == "KAU-INTERNET" && ap.level >= threshold).toList();

    if (results.isNotEmpty) {
      results.sort((a, b) => b.level.compareTo(a.level));
    } else {
      return null;
    }

    while (topAPs.length < 2 && results.isNotEmpty) {
      WiFiAccessPoint currentAP = results.first;
      results.remove(currentAP);

      Database dbInstance = await DatabaseHelper.database;
      GridLocation? APLocation = await getLocationFromDB(dbInstance, currentAP.bssid);

      if (APLocation != null) {
        topAPs[currentAP] = APLocation;
      }
    }
    
    if (topAPs.length == 2) {
      return _estimatePosition(topAPs);
    }
    return null;
  }

  static Future<GridLocation?> getLocationFromDB(Database db, String bssid) async {
    final ResultSet result = db.select(
      'SELECT x, y, floor FROM access_points WHERE bssid = ?',
      [bssid],
    );

    if (result.isNotEmpty) {
      final row = result.first;
      return GridLocation(
        x: row['x'],
        y: row['y'],
        floor: row['floor'],
      );
    }
    return null;
  }

  static GridLocation? _estimatePosition(Map<WiFiAccessPoint, GridLocation> ref) {
    double weightedX = 0, weightedY = 0, totalWeight = 0;
    // int floor1 = ref.values.first.floor;
    // int floor2 = ref.values.last.floor;

    ref.forEach((key, value) {
      double x = value.x;
      double y = value.y;
      int rssi = key.level;

      double distance = estimateDistance(rssi);
      double weight = 1 / (distance + 1e-6);

      weightedX += x * weight;
      weightedY += y * weight;
      totalWeight += weight;
    });

    if (totalWeight > 0) {
      double estimatedX = weightedX / totalWeight;
      double estimatedY = weightedY / totalWeight;
      GridLocation gridLocation = GridLocation(x: estimatedX, y: estimatedY);
      // if(floor1 != floor2) {gridLocation.floor=-1;}
      // else{gridLocation.floor=floor1;}
      return gridLocation;
    }
    return null;
  }

  static double estimateDistance(int rssi) {
    const double n = 2.0;
    const double txPower = -50;
    return math.pow(10, (txPower - rssi) / (10 * n)).toDouble();
  }
}
