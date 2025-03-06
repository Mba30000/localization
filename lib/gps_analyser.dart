import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:indoornav/GridLocation.dart';
import 'package:indoornav/DatabaseHelper.dart';
import 'dart:math' as math;
import 'package:sqlite3/sqlite3.dart';

class GPSAnalyser {
  static int floorLevel = 1;
  static Future<Position?> getGPSLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    return await Geolocator.getCurrentPosition();
  }

// Function to get nearest grid based on GPS coordinates
static Future<GridLocation> mapGPS(double latitude, double longitude) async {
  double shortestDistance = 5000;
  Database? db = await DatabaseHelper.database;
  if (db == null) {
    print("Database is not open.");
    throw Exception("Database is not open.");
  }

  // Query the location data from the database
  final List<Map<String, dynamic>> locations = await DatabaseHelper.queryLocationData(floorLevel);
  if (locations.isEmpty) {
    print("No locations found in the database.");
    throw Exception("No locations found.");
  }

  GridLocation nearestGridLocation = GridLocation();
  print("Total locations fetched: ${locations.length}");

  for (var location in locations) {
    double estimatedLat = double.tryParse(location['min_lat'].toString()) ?? 0.0;
    double estimatedLon = double.tryParse(location['min_lon'].toString()) ?? 0.0;

    double distance = haversine(latitude, longitude, estimatedLat, estimatedLon);
    if(distance <= shortestDistance){
      shortestDistance = distance;
      nearestGridLocation = GridLocation(x:double.tryParse(location['Grid_x'].toString()) ?? 0.0, y: double.tryParse(location['Grid_y'].toString()) ?? 0.0);
    }
    // print("Grid (${location['Grid_x']}, ${location['Grid_y']}) -> Estimated: ($estimatedLat, $estimatedLon), Distance: $distance km");


    
  }

  print("Nearest grid: ${nearestGridLocation.x}, ${nearestGridLocation.y}");
  return nearestGridLocation;
}


  static double haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    double dlat = (lat2 - lat1).abs() * (math.pi / 180);
    double dlon = (lon2 - lon1).abs() * (math.pi / 180);

    double a = math.sin(dlat / 2) * math.sin(dlat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dlon / 2) * math.sin(dlon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }
}
