import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

void main() {
  runApp(MaterialApp(
    home: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String locationMessage = "Press the button to get location";
  Position? gpsPosition;
  List<WiFiAccessPoint> wifiList = [];
  String strongestAP = "No AP found";
  String ssid = "None";
  int strongestSignal = -100;
  TextEditingController xController = TextEditingController();
  TextEditingController yController = TextEditingController();
  String dataFilePath = "";

  @override
  void initState() {
    super.initState();
    _initializeFilePath();
  }

  Future<void> _initializeFilePath() async {
    Directory dir = await getApplicationDocumentsDirectory();
    setState(() {
      dataFilePath = '${dir.path}/logged_aps.json';
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => locationMessage = "Location services are disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => locationMessage = "Location permissions are denied.");
        return;
      }
    }

    gpsPosition = await Geolocator.getCurrentPosition();
    setState(() {
      locationMessage = "GPS: Lat: ${gpsPosition!.latitude}, Lon: ${gpsPosition!.longitude} GPS Accuracy: ±${gpsPosition!.accuracy.toStringAsFixed(2)}m";
    });

    if (Platform.isAndroid) {
      _scanWifiNetworks();
    }
  }



  Future<void> _scanWifiNetworks() async {
    await WiFiScan.instance.startScan();
    List<WiFiAccessPoint> results = await WiFiScan.instance.getScannedResults();
    setState(() {
      wifiList = results;
    });
    _estimatePosition();
  }

void _estimatePosition() async {
  List<Map<String, dynamic>> recordedAPs = await _readLoggedAPs();
  if (recordedAPs.isEmpty) {
    setState(() {
      locationMessage = "No recorded APs found for localization.";
    });
    return;
  }

  List<Map<String, dynamic>> matchingAPs = recordedAPs
      .where((ap) => wifiList.any((wifi) => wifi.bssid == ap['bssid']))
      .toList();

  if (matchingAPs.isEmpty) {
    setState(() {
      locationMessage += "\nNo nearby matching APs found for localization.";
    });
    return;
  }

  // Sort matching APs by signal strength (highest to lowest)
  matchingAPs.sort((a, b) {
    int levelA = wifiList.firstWhere((wifi) => wifi.bssid == a['bssid']).level;
    int levelB = wifiList.firstWhere((wifi) => wifi.bssid == b['bssid']).level;
    return levelB.compareTo(levelA); // Descending order
  });

  // Get the two strongest APs
  var strongestAPs = matchingAPs.take(2).toList();

  double weightedX = 0, weightedY = 0, totalWeight = 0;
  double totalVariance = 0;

  for (var ap in strongestAPs) {
    String bssid = ap['bssid'];
    double x = ap['x'];
    double y = ap['y'];
    int rssi = wifiList.firstWhere((wifi) => wifi.bssid == bssid).level;

    // Estimate distance using the RSSI value
    double distance = estimateDistance(rssi);

    // Calculate weight inversely proportional to distance
    double weight = 1 / (distance + 1e-6); // Prevent division by zero

    // Accumulate weighted coordinates and weights
    weightedX += x * weight;
    weightedY += y * weight;
    totalWeight += weight;

    // Sum of squared distances (for accuracy)
    totalVariance += pow(distance, 2);
  }

  if (totalWeight > 0) {
    double estimatedX = weightedX / totalWeight;
    double estimatedY = weightedY / totalWeight;
    double accuracy = sqrt(totalVariance / strongestAPs.length); // Standard deviation approximation

    setState(() {
      locationMessage += "\nEstimated Position: ($estimatedX, $estimatedY)\nWiFi Accuracy: ±${accuracy.toStringAsFixed(2)}m";
    });
  } else {
    setState(() {
      locationMessage += "\nNo valid APs found for position estimation.";
    });
  }
}


Future<List<Map<String, dynamic>>> _readLoggedAPs() async {
  try {
    final file = File(dataFilePath);
    if (!await file.exists()) return [];

    String contents = await file.readAsString();
    List<dynamic> jsonData = json.decode(contents);

    return jsonData.map((item) => Map<String, dynamic>.from(item)).toList();
  } catch (e) {
    print("Error reading file: $e");
    return [];
  }
}

  double estimateDistance(int rssi) {
    const double n = 2.0;
    const double txPower = -50;
    return pow(10, (txPower - rssi) / (10 * n)).toDouble();
  }

  void _showCoordinateInput(String bssid, String ssid, int signal) {
    xController.clear();
    yController.clear();
    setState(() {
      strongestAP = bssid;
      strongestSignal = signal;
    });
    showDialog(
      context: context,
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _recordGpsLocation(bssid, ssid, signal); // Proceed to log GPS data
              },
              child: Text("Next"),
            ),
          ],
        );
      },
    );
  }


  Future<void> _logAccessPoint() async {
    if (!Platform.isAndroid) return;

    await WiFiScan.instance.startScan();
    List<WiFiAccessPoint> results = await WiFiScan.instance.getScannedResults();

    results = results.where((ap) => ap.ssid == "KAU-INTERNET").toList();

    if (results.isNotEmpty) {
      results.sort((a, b) => b.level.compareTo(a.level));
      String strongestBSSID = results.first.bssid;
      int strongestSignal = results.first.level;
      String ssid = results.first.ssid;

      _showCoordinateInput(strongestBSSID, ssid, strongestSignal); // Prompt user for coordinates
    } else {
      print("No matching APs found for the specified SSID.");
    }
  }

  Future<void> _recordGpsLocation(String bssid, String ssid, int signal) async {
    if (!Platform.isAndroid) return;

    // Record GPS location multiple times for accuracy
    List<Position> positions = [];
    for (int i = 0; i < 10; i++) {
      positions.add(await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high));
    }

    Position bestPosition = positions.reduce((a, b) => a.accuracy < b.accuracy ? a : b);

    // Create a map for logging
    Map<String, dynamic> apData = {
      'bssid': bssid,
      'ssid': ssid,
      'signal': signal,
      'x': double.tryParse(xController.text) ?? 0,
      'y': double.tryParse(yController.text) ?? 0,
      'latitude': bestPosition.latitude,
      'longitude': bestPosition.longitude,
      'accuracy': bestPosition.accuracy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    String jsonString = json.encode(apData);
    Directory appDocDir = await getApplicationDocumentsDirectory();
    File logFile = File('${appDocDir.path}/logged_aps.json');

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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Indoor Positioning App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(locationMessage),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              child: Text("Get Location"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _logAccessPoint,
              child: Text("Log Access Point"),
            ),
          ],
        ),
      ),
    );
  }
}
