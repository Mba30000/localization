import 'package:flutter/material.dart';
import 'dart:async';
import 'package:indoornav/gps_analyser.dart';
import 'package:indoornav/imuReader.dart';
import 'package:indoornav/wifi_analyser.dart';
import 'package:indoornav/GridLocation.dart';
import 'package:indoornav/ap_recorder.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:indoornav/imuReader.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}



class _MyAppState extends State<MyApp> {
  String locationMessage = "Finding GPS coordinates...";
  String buttonText = "Start";
  String strongestAP = "No AP found";
  int strongestSignal = -100;
  bool isRecording = false;
  Timer? timer;
  TextEditingController wifiController = TextEditingController();
  TextEditingController gpsController = TextEditingController();
  ImuReader imuReader = ImuReader();
  Map<String, dynamic>? imuData;
  int? floor = -1;

@override
  void initState() {
    super.initState();
    // startBackgroundFloorChangeDetection();  // Start the periodic task when the app starts
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

void _toggleLocationUpdates() {
  if (isRecording) {
    setState(() {
      isRecording = false;
      buttonText = "Start";
    });
    timer?.cancel();
  } else {
    setState(() {
      isRecording = true;
      buttonText = "Stop";
    });

    timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      String newLocation = await _getCurrentLocation();
      setState(() {
        locationMessage = newLocation; 
      });
    });
  }
}

void startBackgroundFloorChangeDetection() {
  Timer.periodic(Duration(seconds: 1), (timer) {
    setState(() {
      imuReader.startReading();
      imuData = imuReader.getImuData();  // Track IMU Z-axis data
    });
  });
}

Future<String> _getCurrentLocation() async {
  // Get current GPS position
  Position? position = await GPSAnalyser.getGPSLocation();

  // Define thresholds
  double gpsThreshold = (gpsController.text.isEmpty) ? 15.0 : double.tryParse(gpsController.text) ?? 18.0;
  double wifiThreshold = (wifiController.text.isEmpty) ? -80 : double.tryParse(wifiController.text) ?? -80;

  int? newFloor = await WiFiBLEPositioning.checkFloorBLE(wifiThreshold);
  if(newFloor != -1){
    floor = newFloor;
  }
  // If GPS accuracy is good enough, use GPS location
  if (position != null && position.accuracy < gpsThreshold) {
    GridLocation gridLocation = await GPSAnalyser.mapGPS(position.latitude, position.longitude, floor);
    // gridLocation.floor = 1 + delta;
    return "$gridLocation found using GPS";
  }

  // Otherwise, attempt WiFi-based location
  GridLocation? gridLocation = await WiFiBLEPositioning.estimatePosition(wifiThreshold);
  gridLocation?.floor = (floor)!;
  if(gridLocation != null){
    // gridLocation.floor = 1 + delta;
    }
  if (gridLocation != null) {
    return "$gridLocation found using Wifi";
  }

  // If neither GPS nor WiFi works, return a failure message
  return "None of the methods worked";
}



  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Location Estimation')),
          body: Column(
            children: <Widget>[
              Text(locationMessage),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _toggleLocationUpdates,
                child: Text(buttonText),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // _logAccessPoint(context);
                },
                child: Text("Log Access Point"),
              ),
              SizedBox(height: 20),
              Text(imuData.toString()),
              TextField(
              controller: gpsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "GPS Threshold"),
            ),TextField(
              controller: wifiController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Wifi Threshold"),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class CoordinateInputScreen extends StatelessWidget {
  final String bssid;
  final String ssid;
  final int signal;
  final TextEditingController xController = TextEditingController();
  final TextEditingController yController = TextEditingController();
  final TextEditingController floorController = TextEditingController();

  CoordinateInputScreen({required this.bssid, required this.ssid, required this.signal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Enter AP Coordinates")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    APRecorder.recordGpsLocation(
                      bssid, 
                      ssid, 
                      signal, 
                      double.tryParse(xController.text) ?? 0.0, // ✅ Safe conversion
                      double.tryParse(yController.text) ?? 0.0, // ✅ Converts Y coordinate
                      double.tryParse(floorController.text) ?? 1.0   // ✅ Converts Floor to Integer
                    );

                    Navigator.pop(context);
                  },
                  child: Text("Save"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
