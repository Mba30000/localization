import 'dart:io';
import 'package:indoornav/GridLocation.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:typed_data';
import 'dart:math';

class DatabaseHelper {
  static Database? _db;

  // Get the database (or create it if it doesn't exist)
  static Future<Database> get database async {
    if (_db != null) return _db!;

    // Get application document directory
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String dbPath = join(appDocDir.path, 'location.db');

    // If the database doesn't exist, copy it from assets
    // if (!await File(dbPath).exists()) {
      ByteData data = await rootBundle.load('assets/backend/location.db');
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPath).writeAsBytes(bytes, flush: true);
    // }

    // Open the database (this version uses sqlite3 package)
    _db = sqlite3.open(dbPath); // ✅ Uses full SQLite with R-Tree
    return _db!;
  }

static Future<List<Map<String, dynamic>>> queryLocationData(int floorLevel) async {
  final db = await database;
  try {
    // Map floor levels to their corresponding column names
    final Map<int, String> floorColumns = {
      1: 'm.firstFloor_paths',
      2: 'm.secondFloor_paths',
      // Add more floors as needed
    };

    // Default to first floor if floorLevel is invalid
    String floorColumn = floorColumns[floorLevel] ?? 'm.firstFloor_paths';

    final ResultSet result = db.select('''
      SELECT l.Grid_x, l.Grid_y, l.min_lat, l.min_lon, m.swap_needed
      FROM location_rtree l
      LEFT JOIN location_tree_metadata m
      ON l._rowid_ = m.id
      WHERE $floorColumn = 1
    ''');

    return result.map((row) {
      // Check if swap is needed
      final bool swap = row['swap_needed'] == 1;

      return {
        'Grid_x': swap ? row['Grid_y'] : row['Grid_x'], // Swap if needed
        'Grid_y': swap ? row['Grid_x'] : row['Grid_y'], // Swap if needed
        'min_lat': row['min_lat'],
        'min_lon': row['min_lon'],
      };
    }).toList();
  } catch (e) {
    print('Error querying location data: $e');
    return [];
  }
}



static Future<GridLocation?> queryClosestLocationForFloor(int floorLevel, GridLocation? gridLocation) async {
  if (gridLocation == null) return null; // Ensure gridLocation is not null
  
  final db = await database;

  try {
    // Map floor levels to their corresponding column names
    final Map<int, String> floorColumns = {
      1: 'm.firstFloor_paths',
      2: 'm.secondFloor_paths',
      // Extend for additional floors if needed
    };

    // Get floor column, defaulting to first floor if missing
    String? floorColumn = floorColumns[floorLevel];
    if (floorColumn == null) {
      print("Warning: Floor level $floorLevel not mapped. Defaulting to first floor.");
      floorColumn = 'm.firstFloor_paths';
    }

    // Select all locations where the floor column equals 1
    final ResultSet result = db.select('''
      SELECT l.Grid_x, l.Grid_y
      FROM location_rtree l
      LEFT JOIN location_tree_metadata m ON l._rowid_ = m.id
      WHERE $floorColumn = 1
    ''');

    // Convert the result rows to GridLocation objects
    List<GridLocation> locations = [];
    for (var row in result) {
      locations.add(GridLocation(
        x: (row['Grid_x'] as num).toDouble(),
        y: (row['Grid_y'] as num).toDouble(),
        floor: floorLevel, // Fallback to given floor if no floor data in DB
      ));
    }

    // If no locations found, return null
    if (locations.isEmpty) return null;

    // Calculate the closest location based on Euclidean distance
    GridLocation closestLocation = locations.first;
    double closestDistance = double.infinity;

    for (var location in locations) {
      double distance = _calculateEuclideanDistance(gridLocation, location);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestLocation = location;
      }
    }

    return closestLocation;
  } catch (e) {
    print('Error querying location data: $e');
    return null;
  }
}

static double _calculateEuclideanDistance(GridLocation point1, GridLocation point2) {
  double dx = point1.x - point2.x;
  double dy = point1.y - point2.y;
  return sqrt(dx * dx + dy * dy); // Euclidean distance formula
}

  // Query for access points based on BSSID (to be used separately if needed)
  static List<Map<String, dynamic>> queryAccessPoint(Database db, String bssid) {
    final ResultSet result = db.select(
      'SELECT x, y, floor FROM access_points WHERE bssid = ?',
      [bssid]
    );

    return result.map((row) => {
      'x': row['x'],
      'y': row['y'],
      'floor': row['floor'],
    }).toList();
  }
}


