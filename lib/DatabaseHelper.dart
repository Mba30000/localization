import 'dart:io';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:typed_data';

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


