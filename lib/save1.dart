import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'dart:math';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String locationMessage = "Press the button to get location";
  Position? gpsPosition;
  List<WiFiAccessPoint> wifiList = [];
  
  // AP coordinates
  final Map<String, List<double>> apCoordinates = {
    "d0:c7:89:67:99:b1": [5.5, 10],
    "c0:68:03:39:cc:51": [11, 9],
    "d0:c7:89:c6:8d:a1": [17, 9]
  };

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

    getLocationSource();
    _scanWifiNetworks();
  }

  Future<void> _scanWifiNetworks() async {
    await WiFiScan.instance.startScan();
    List<WiFiAccessPoint> results = await WiFiScan.instance.getScannedResults();
    setState(() {
      wifiList = results;
    });
    _estimatePosition();
  }

  double estimateDistance(int rssi) {
    const double n = 2.0; // Path loss exponent
    const double txPower = -40; // Approximate transmit power at 1m
    return pow(10, (txPower - rssi) / (10 * n)).toDouble();
  }

  void _estimatePosition() {
    double weightedX = 0, weightedY = 0, totalWeight = 0;
    double totalVariance = 0;

    for (var wifi in wifiList) {
      if (apCoordinates.containsKey(wifi.bssid)) {
        double distance = estimateDistance(wifi.level);
        double weight = 1 / (distance + 1e-6); // Prevent division by zero
        weightedX += apCoordinates[wifi.bssid]![0] * weight;
        weightedY += apCoordinates[wifi.bssid]![1] * weight;
        totalWeight += weight;
        totalVariance += pow(distance, 2); // Sum of squared distances
      }
    }

    if (totalWeight > 0) {
      double estimatedX = weightedX / totalWeight;
      double estimatedY = weightedY / totalWeight;
      double accuracy = sqrt(totalVariance / wifiList.length); // Standard deviation approximation

      setState(() {
        locationMessage += "\nEstimated Position: ($estimatedX, $estimatedY)\nWiFi Accuracy: ±${accuracy.toStringAsFixed(2)}m";
      });
    } else {
      setState(() {
        locationMessage += "\nNo WiFi APs detected for estimation.";
      });
    }
  }

  void getLocationSource() async {
    Position position = await Geolocator.getCurrentPosition();
    print("Latitude: \${position.latitude}, Longitude: \${position.longitude}");
    print("Location source: \${position.source}");
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
              ElevatedButton(
                onPressed: _getCurrentLocation,
                child: Text("Get Location & Estimate Position"),
              ),
              SizedBox(height: 20),
              Text(locationMessage, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
