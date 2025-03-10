

import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'dart:math' as math;
import 'package:indoornav/GridLocation.dart';
import 'package:indoornav/DatabaseHelper.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';


class WiFiBLEPositioning {
  static bool isScanning = false; // Flag to manage scan state
  static Future<GridLocation?> estimatePosition(double threshold) async {
    Map<Object, GridLocation>? topAnchors = {};
    // await FlutterBluePlus.startScan();
    List<ScanResult> bleResults = await _scanBLE();
    List<Object> wifiResults = [];
    if (Platform.isAndroid){
      wifiResults = await WiFiScan.instance.getScannedResults();
      wifiResults = wifiResults.where((ap) => (ap as WiFiAccessPoint).ssid == "KAU-INTERNET" && ap.level >= threshold).toList();
    }
    Map<String, ScanResultCopy> uniqueResults = {}; 
    List<ScanResultCopy> bleResultsCopy = [];
    bleResults.where((bleResult) => bleResult.rssi >= threshold)
      .forEach((bleResult) {
      uniqueResults[bleResult.device.remoteId.toString()] = ScanResultCopy(deviceId: bleResult.device.remoteId.toString().toLowerCase(), rssi: bleResult.rssi); // Only keep the latest result for each BSSID
    });

    // Convert back to list
    bleResultsCopy = uniqueResults.values.toList();

    List<Object> results = [...wifiResults, ...bleResultsCopy];
    topAnchors = await filter(results, topAnchors);
    print("${topAnchors?.length} Beacons Found");
    GridLocation? gridLocation = _estimatePosition(topAnchors);
    return await DatabaseHelper.queryClosestLocationForFloor(1, gridLocation);
  }

  static Future<int?> checkFloorWifi(int threshold) async{
    List<WiFiAccessPoint> wifiResults = await WiFiScan.instance.getScannedResults();
    wifiResults = wifiResults.where((ap) => ap.ssid == "KAU-INTERNET" && ap.level >= threshold).toList();
    return DatabaseHelper.getFloorIfChanged(wifiResults.first.bssid);
  }

  static Future<int?> checkFloorBLE(double threshold) async{
    List<ScanResult> bleResults = await _scanBLE();
    Map<String, ScanResultCopy> uniqueResults = {}; 
    List<ScanResultCopy> bleResultsCopy = [];
    bleResults.where((bleResult) => bleResult.rssi >= threshold)
      .forEach((bleResult) {
      uniqueResults[bleResult.device.remoteId.toString()] = ScanResultCopy(deviceId: bleResult.device.remoteId.toString().toLowerCase(), rssi: bleResult.rssi); // Only keep the latest result for each BSSID
    });

    // Convert back to list
    bleResultsCopy = uniqueResults.values.toList();
    if(bleResultsCopy.isEmpty){return -1;}
    return DatabaseHelper.getFloorIfChanged(bleResultsCopy.first.deviceId);
  }

  static Future<Map<Object, GridLocation>?> filter(List<Object> results, Map<Object, GridLocation>? topAnchors) async {
  if (results.isNotEmpty) {
    results.sort((a, b) {
      if (a is WiFiAccessPoint && b is WiFiAccessPoint) {
        return b.level.compareTo(a.level); // WiFi uses `level`
      } else if (a is ScanResultCopy && b is ScanResultCopy) {
        return b.rssi.compareTo(a.rssi); // BLE uses `rssi`
      } else if (a is WiFiAccessPoint && b is ScanResultCopy) {
        return b.rssi.compareTo(a.level); // Compare WiFi `level` with BLE `rssi`
      } else if (a is ScanResultCopy && b is WiFiAccessPoint) {
        return b.level.compareTo(a.rssi);
      }
      return 0; // Fallback
    });
  } else {
    return null;
  }

  // Filter top 2
  while (topAnchors != null && topAnchors.length < 2 && results.isNotEmpty) {
    Object currentAnchor = results.first;
    results.removeAt(0); // Remove first element

    String? id;
    if (currentAnchor is WiFiAccessPoint) {
      id = currentAnchor.bssid; // WiFi BSSID
    } else if (currentAnchor is ScanResultCopy) {
      id = currentAnchor.deviceId; // BLE Unique ID
    }

    if (id == null) continue; // Skip if no valid identifier

    Database dbInstance = await DatabaseHelper.database;
    GridLocation? location = await getLocationFromDB(dbInstance, id);
    if(location?.x == null){continue;}
      print(" Beacon: (${location?.x}, ${location?.y})");
    if (location != null) {
      topAnchors[currentAnchor] = location;
    }
    print("${topAnchors?.length} Beacons Found");
  }
  return topAnchors;
}

  static Future<GridLocation?> getLocationFromDB(Database db, String bssid) async {
    final ResultSet result = db.select(
      'SELECT x, y, floor FROM access_points WHERE bssid = ?',
      [bssid],
    );

    if (result.isNotEmpty) {
      final row = result.first;
      return GridLocation(
        x: (row['x'] as num).toDouble(),
        y: (row['y'] as num).toDouble(),
        floor: row['floor'] as int, // Ensure this is an int
      );
    }

    return null;
  }

static Future<List<ScanResult>> _scanBLE() async {
  List<ScanResult> results = [];
  Completer<List<ScanResult>> completer = Completer();

  if (isScanning) return results; // Prevent scanning if already in progress

  isScanning = true;

  // List of iBeacon UUIDs (Replace with actual UUIDs from your beacons)
  List<Guid> serviceUuids = [
    Guid("E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"), // Example iBeacon UUID
  ];

  // Start scanning with UUID filtering on iOS
  FlutterBluePlus.startScan(
    withServices: Platform.isIOS ? serviceUuids : [], // Only filter for iBeacon UUIDs on iOS
  );

  StreamSubscription? subscription = FlutterBluePlus.scanResults.listen((List<ScanResult> scanResults) {
    for (var scanResult in scanResults) {
      // iOS: Check if the scanned beacon has a matching UUID
      if (Platform.isIOS &&
          scanResult.advertisementData.serviceUuids.any((uuid) => serviceUuids.contains(uuid))) {
        // Only add iBeacon results with matching UUIDs
        results.add(scanResult);
        print(scanResult.toString());
      } 
      // Android: Accept all BLE beacons (no UUID filtering, but you can add filters for iBeacons)
      else if (Platform.isAndroid) {
        results.add(scanResult);
        print(scanResult.toString());
      }
    }
  });

  await Future.delayed(Duration(seconds: 2)); // Allow some time for scanning
  FlutterBluePlus.stopScan();
  await subscription?.cancel();
  isScanning = false;
  completer.complete(results);

  return completer.future;
}

  static GridLocation? _estimatePosition(Map<Object, GridLocation>? ref) {
    double weightedX = 0, weightedY = 0, totalWeight = 0;
    if(ref==null){return null;}

    ref.forEach((key, value) {
      double x = value.x;
      double y = value.y;
      int rssi = (key is WiFiAccessPoint) ? key.level : (key as ScanResultCopy).rssi;

      double distance = estimateDistance(rssi);
      double weight = 1 / (distance + 1e-6);

      weightedX += x * weight;
      weightedY += y * weight;
      totalWeight += weight;
      print(" Beacon: (${x}, ${y})");
    });

    if (totalWeight > 0) {
      double estimatedX = weightedX / totalWeight;
      double estimatedY = weightedY / totalWeight;
      GridLocation gridLocation = GridLocation(x: estimatedX, y: estimatedY);
      
      print(" Calculated: (${gridLocation.x}, ${gridLocation.y}; floor -> ${gridLocation.floor} )");
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

class ScanResultCopy {
  final String deviceId;
  final int rssi;

  ScanResultCopy({
    required this.deviceId,
    required this.rssi,
  });
}