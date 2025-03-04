import 'dart:developer';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wifi_scan/wifi_scan.dart';

import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart'; 
import 'dart:collection';
import 'dart:typed_data';
import 'dart:io';

//import 'package:flutter_sensors/flutter_sensors.dart';
//import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:indoornav/GridLocation.dart';
import 'package:indoornav/DatabaseHelper.dart';
void main() {
  runApp(MaterialApp(
    home: MyApp(),
  ));
  // BackgroundService().initialize();
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String locationMessage = "This is an indoor localization Demo";
  List<WiFiAccessPoint> wifiList = [];
  TextEditingController xController = TextEditingController();
  TextEditingController yController = TextEditingController();
  TextEditingController floorController = TextEditingController();
  String strongestAP = "No AP found";
  int strongestSignal = -100;
  String _logFile = "";
  String buttonText = "Play";
  Database? db;
  int currentFloor = 0;

@override
void initState() {
  super.initState();
  _initializeFilePath();
}


  Future<void> _initializeFilePath() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    _logFile = "${appDocDir.path}/logged_aps.json";
  }


  Future<void> _recordGpsLocation(String bssid, String ssid, int signal) async {
    if (!Platform.isAndroid) return;

    // Record GPS location multiple times for accuracy
    List<Position> positions = [];
    for (int i = 0; i < 10; i++) {
      Position? pos = await _getGPSLocation();
      if(pos == null){
        return;
      }
      Position position = pos;
      positions.add(position);
    }

    Position bestPosition = positions.reduce((a, b) => a.accuracy < b.accuracy ? a : b);

    // Create a map for logging
    Map<String, dynamic> apData = {
      'bssid': bssid,
      'ssid': ssid,
      'signal': signal,
      'x': double.tryParse(xController.text) ?? 0,
      'y': double.tryParse(yController.text) ?? 0,
      'floor' : double.tryParse(floorController.text) ?? 0,
      'latitude': bestPosition.latitude,
      'longitude': bestPosition.longitude,
      'accuracy': bestPosition.accuracy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    String jsonString = json.encode(apData);
    File logFile =File(_logFile);

    // Append new AP data or create new file if doesn't exist
    if (await logFile.exists()) {
      String fileContent = await logFile.readAsString();
      List<dynamic> jsonData = json.decode(fileContent);
      jsonData.add(apData);
      await logFile.writeAsString(json.encode(jsonData));
    } else {
      await logFile.writeAsString(json.encode([apData]));
    }

    print("Access point and GPS data logged.");
  }



void _showCoordinateInput(String bssid, String ssid, int signal, BuildContext context) {
  // Clear the text controllers when dialog is invoked
  xController.clear();
  yController.clear();
  floorController.clear();

  // Update state with the selected AP details
  setState(() {
    strongestAP = bssid;
    strongestSignal = signal;
  });

  // Show dialog to get coordinates
  showDialog(
    context: context,  // Correctly pass the context here
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Enter AP Coordinates"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("SSID: $ssid"),
            Text("BSSID: $bssid"),
            Text("Signal Strength: $signal dBm"),
            TextField(
              controller: xController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "X Coordinate"),
            ),
            TextField(
              controller: yController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Y Coordinate"),
            ),
            TextField(
              controller: floorController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Floor Num"),
            ),
          ],
        ),
        actions: [
          // Cancel button: closes the dialog
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("Cancel"),
          ),
          // Next button: closes the dialog and proceeds with logging GPS data
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _recordGpsLocation(bssid, ssid, signal); // Log the location
            },
            child: Text("Next"),
          ),
        ],
      );
    },
  );
}

  Future<void> _logAccessPoint(BuildContext context) async {
    if (!Platform.isAndroid) return;

    await WiFiScan.instance.startScan();
    List<WiFiAccessPoint> results = await WiFiScan.instance.getScannedResults();

    results = results.where((ap) => ap.ssid == "KAU-INTERNET").toList();

    if (results.isNotEmpty) {
      results.sort((a, b) => b.level.compareTo(a.level));
      String strongestBSSID = results.first.bssid;
      int strongestSignal = results.first.level;
      String ssid = results.first.ssid;

      _showCoordinateInput(strongestBSSID, ssid, strongestSignal, context); // Prompt user for coordinates
    } else {
      print("No matching APs found for the specified SSID.");
    }
  }

  Future<Position?> _getGPSLocation() async{
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => locationMessage = "Location services are disabled.");
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => locationMessage = "Location permissions are denied.");
        return null;
      }
    }

    Position? gpsPosition = await Geolocator.getCurrentPosition();
    return gpsPosition;
  }
double haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371; // Radius of the Earth in kilometers
  
  // Convert degrees to radians
  double dlat = (lat2 - lat1).abs();
  double dlon = (lon2 - lon1).abs();

  dlat = (dlat * math.pi) / 180.0; // Convert to radians
  dlon = (dlon * math.pi) / 180.0; // Convert to radians

  // Haversine formula
  double a = math.sin(dlat / 2) * math.sin(dlat / 2) +
      math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) *
      math.sin(dlon / 2) * math.sin(dlon / 2);
      
  double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return R * c; // Distance in kilometers
}

Future<GridLocation> _mapGPS(double latitude, double longitude) async {
  db = await DatabaseHelper.database; // Ensure DB is initialized
  if (db == null) {
    throw Exception("Database is not open.");
  }

  final List<Map<String, dynamic>> grids = await DatabaseHelper.queryLocationData();

  GridLocation nearestGridLocation = GridLocation();
  double minDistance = double.infinity;

  for (var grid in grids) {
    double grid_x = grid['grid_x'];
    double grid_y = grid['grid_y'];
    double min_lat = grid['min_lat'];
    double min_lon = grid['min_lon'];
    int swapNeeded = grid['swap_needed'];

    if (swapNeeded == 1) {
      double temp = grid_x;
      grid_x = grid_y;
      grid_y = temp;
    }

    double distance = haversine(latitude, longitude, min_lat, min_lon);

    if (distance < minDistance) {
      minDistance = distance;
      nearestGridLocation = GridLocation(x: grid_x, y: grid_y);
    }
  }
  return nearestGridLocation;
}



Future<GridLocation?> _estPosWifi() async {
  if (!Platform.isAndroid) return null;

  Set<String> uniqueBSSIDs = {};
  Map<WiFiAccessPoint,GridLocation> topAPs = {};
  List<WiFiAccessPoint> results = await WiFiScan.instance.getScannedResults();
    
    // Filter for the target SSID
    results = results.where((ap) => ap.ssid == "KAU-INTERNET").toList();

    if (results.isNotEmpty) {
      // Sort by signal strength (descending order)
      results.sort((a, b) => b.level.compareTo(a.level));
    } else {
      return null;
    }

  while (topAPs.length < 2 && results.isNotEmpty) {
    WiFiAccessPoint currentAP = results.first;
    
    results.remove(currentAP);
    Database dbInstance = await DatabaseHelper.database;
    GridLocation? APLocation = await getLocationFromDB(dbInstance, currentAP.bssid);

    if(APLocation != null){
      topAPs.addEntries({MapEntry(currentAP, APLocation)});
    }
  }
  if(topAPs.length == 2){
    return _estimatePosition(topAPs);
  }
  return null; // Modify to return meaningful data if needed
}






Future<GridLocation?> _estimatePosition(Map<WiFiAccessPoint,GridLocation> ref) async {
  double weightedX = 0, weightedY = 0, totalWeight = 0;

  ref.forEach((key, value) {
    if(value.floor != currentFloor){
      currentFloor = value.floor;
    }
    double x = value.x;
    double y = value.y;
    int rssi = key.level;

    // Estimate distance using the RSSI value
    double distance = estimateDistance(rssi);

    // Calculate weight inversely proportional to distance
    double weight = 1 / (distance + 1e-6); // Prevent division by zero

    // Accumulate weighted coordinates and weights
    weightedX += x * weight;
    weightedY += y * weight;
    totalWeight += weight;
  });

  if (totalWeight > 0) {
    double estimatedX = weightedX / totalWeight;
    double estimatedY = weightedY / totalWeight;
    return GridLocation(x:estimatedX,y:estimatedY);
  } 
  return null;
}



  double estimateDistance(int rssi) {
    const double n = 2.0;
    const double txPower = -50;
    return math.pow(10, (txPower - rssi) / (10 * n)).toDouble();
  }

Future<GridLocation?> getLocationFromDB(Database db, String bssid) async {
  final ResultSet result = db.select(
    'SELECT x, y, floor FROM access_points WHERE bssid = ?',
    [bssid]
  );

  if (result.isNotEmpty) {
    final row = result.first;
    return GridLocation(
      x: row['x'], // Coordinate value
      y: row['y'], // Coordinate value
      floor: row['floor'], // Floor value
    );
  }

  return null; // Return null if no matching result is found
}


Future<void> _getCurrentLocation() async {
  // Check GPS Accuracy <15m is considered Acceptable 
  Position? position = await _getGPSLocation();
      if(position == null){
        return;
      }else if(position.accuracy > 30){
        setState(() {
        locationMessage = "finding location using wifi";
        });
        // Check via Wifi proximity 
        GridLocation? gridLocation = await _estPosWifi();
        setState(() {
        locationMessage = gridLocation.toString();
        locationMessage+="Found using Wifi";
        });
        return;
      }
  GridLocation gridLocation = await _mapGPS(position.latitude, position.longitude);
  setState(() {
    locationMessage = gridLocation.toString();
    locationMessage+="Found using GPS";
  });
  }


  Future<void>  handleLocation() async{
    if(buttonText=="Play"){
      setState(() {
        locationMessage = "finding gps coordinates";
        buttonText = "Pause";
      });
      
      _getCurrentLocation();
      
    }else{
      setState(() {
        locationMessage = "paused";
        buttonText = "Play";
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Location Estimation')),
        body: Column(
          children: <Widget>[
            Text(locationMessage),
          SizedBox(height: 20),
          ElevatedButton(
              onPressed: handleLocation,
              child: Text(buttonText),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {_logAccessPoint(context);},
              child: Text("Log Access Point"),
            ),
          ],
        ),
      ),
    );
  }
  
}




