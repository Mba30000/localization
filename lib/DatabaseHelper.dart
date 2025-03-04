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
    if (!await File(dbPath).exists()) {
      ByteData data = await rootBundle.load('assets/backend/location.db');
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }

    // Open the database (this version uses sqlite3 package)
    _db = sqlite3.open(dbPath); // ✅ Uses full SQLite with R-Tree
    return _db!;
  }

  // Query to get location data with additional metadata
  static Future<List<Map<String, dynamic>>> queryLocationData() async {
    final db = await database;
    try {
      // Query location and metadata using LEFT JOIN
      final ResultSet result = db.select('''
        SELECT l.grid_x, l.grid_y, l.min_lat, l.min_lon, m.swap_needed
        FROM location_tree l
        LEFT JOIN location_tree_metadata m
        ON l.id = m.id
      ''');

      return result.map((row) => {
        'grid_x': row['grid_x'],
        'grid_y': row['grid_y'],
        'min_lat': row['min_lat'],
        'min_lon': row['min_lon'],
        'swap_needed': row['swap_needed'],
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


