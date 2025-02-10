import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

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
      dataFilePath = '${dir.path}/ap_locations.txt';
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

    gpsPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      locationMessage = "GPS: Lat: ${gpsPosition!.latitude}, Lon: ${gpsPosition!.longitude}GPS Accuracy: ±${gpsPosition!.accuracy.toStringAsFixed(2)}m";
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
    double weightedX = 0, weightedY = 0, totalWeight = 0;
    double totalVariance = 0;

    for (var wifi in wifiList) {
      var recordedAP = recordedAPs.firstWhere(
          (ap) => ap['bssid'] == wifi.bssid,
          orElse: () => {});

      if (recordedAP.isNotEmpty) {
        double distance = estimateDistance(wifi.level);
        double weight = 1 / (distance + 1e-6);
        weightedX += recordedAP['x'] * weight;
        weightedY += recordedAP['y'] * weight;
        totalWeight += weight;
        totalVariance += pow(distance, 2);
      }
    }

    if (totalWeight > 0) {
      double estimatedX = weightedX / totalWeight;
      double estimatedY = weightedY / totalWeight;
      double accuracy = sqrt(totalVariance / wifiList.length);
      setState(() {
        locationMessage += "\nEstimated Position: (\$estimatedX, \$estimatedY)\nWiFi Accuracy: ±\${accuracy.toStringAsFixed(2)}m";
      });
    }
  }
  double estimateDistance(int rssi) {
    const double n = 2.0; // Path loss exponent
    const double txPower = -40; // Approximate transmit power at 1m
    return pow(10, (txPower - rssi) / (10 * n)).toDouble();
  }
void _showCoordinateInput() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Enter AP Coordinates"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Display SSID and BSSID
              Text("SSID: $ssid"),
              Text("BSSID: $strongestAP"),
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
              Navigator.of(context).pop(); // Close dialog
            },
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _recordGpsLocation(); // Proceed to log GPS data
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
  
  // Start Wi-Fi scanning
  await WiFiScan.instance.startScan();
  
  // Retrieve the scanned results
  List<WiFiAccessPoint> results = await WiFiScan.instance.getScannedResults();

  // Debug: Print all scanned results to see if SSID is being detected
  results.forEach((ap) {
    print("SSID: ${ap.ssid}, BSSID: ${ap.bssid}, Signal: ${ap.level}");
  });

  // Filter the results to find the specific SSID (e.g., "HAUWEI-B315-185D")
  results = results.where((ap) => ap.ssid == "HUAWEI-B315-185D").toList();

  // Debug: Log the filtered results
  if (results.isEmpty) {
    print("No access points found with the SSID 'HAUWEI-B315-185D'");
  } else {
    print("Found ${results.length} access points with the SSID 'HAUWEI-B315-185D'");
  }

  // If a matching access point is found, proceed with logging
  if (results.isNotEmpty) {
    // Sort by signal strength (highest to lowest)
    results.sort((a, b) => b.level.compareTo(a.level));

    // Store the strongest AP details
    strongestAP = results.first.bssid;
    strongestSignal = results.first.level;
    ssid = results.first.ssid;

    // Show dialog for user input
    _showCoordinateInput();
  } else {
    // Handle the case where no APs were found
    print("No matching APs found for the specified SSID.");
  }
}

Future<void> _recordGpsLocation() async {
  if (!Platform.isAndroid) return;
  List<Position> positions = [];
  for (int i = 0; i < 10; i++) {
    positions.add(await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high));
  }

  Position bestPosition = positions.reduce((a, b) => a.accuracy < b.accuracy ? a : b);

  File file = File(dataFilePath);
  await file.writeAsString(
    "BSSID: $strongestAP, SSID: $ssid, Signal: $strongestSignal dB, X: ${xController.text}, Y: ${yController.text}, GPS: (${bestPosition.latitude}, ${bestPosition.longitude}), Accuracy: ±${bestPosition.accuracy.toStringAsFixed(2)}m\n",
    mode: FileMode.append,
  );
}


  Future<List<Map<String, dynamic>>> _readLoggedAPs() async {
    File file = File(dataFilePath);
    if (!file.existsSync()) return [];
    List<String> lines = await file.readAsLines();
    return lines.map((line) {
      var parts = line.split(", ");
      return {
        'bssid': parts[0].split(": ")[1],
        'x': double.parse(parts[2].split(": ")[1]),
        'y': double.parse(parts[3].split(": ")[1]),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Location Estimation')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(onPressed: _getCurrentLocation, child: Text("Get Location & Estimate Position")),
              if (Platform.isAndroid) ...[
                SizedBox(height: 10),
                ElevatedButton(onPressed: _logAccessPoint, child: Text("Log Access Point")),
              ],
              SizedBox(height: 20),
              Text(locationMessage, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
