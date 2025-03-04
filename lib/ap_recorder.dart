import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:indoornav/gps_analyser.dart';

class APRecorder {
  static String _logFile = "";

  static Future<void> initializeFilePath() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    _logFile = "${appDocDir.path}/logged_aps.json";
  }

  static Future<void> recordGpsLocation(String bssid, String ssid, int signal, double x, double y, double floor) async {
    if (!Platform.isAndroid) return;

    List<Position> positions = [];
    for (int i = 0; i < 10; i++) {
      Position? pos = await GPSAnalyser.getGPSLocation();
      if (pos == null) return;
      positions.add(pos);
    }

    Position bestPosition = positions.reduce((a, b) => a.accuracy < b.accuracy ? a : b);

    Map<String, dynamic> apData = {
      'bssid': bssid,
      'ssid': ssid,
      'signal': signal,
      'x': x,
      'y': y,
      'floor': floor,
      'latitude': bestPosition.latitude,
      'longitude': bestPosition.longitude,
      'accuracy': bestPosition.accuracy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    File logFile = File(_logFile);
    if (await logFile.exists()) {
      String fileContent = await logFile.readAsString();
      List<dynamic> jsonData = json.decode(fileContent);
      jsonData.add(apData);
      await logFile.writeAsString(json.encode(jsonData));
    } else {
      await logFile.writeAsString(json.encode([apData]));
    }
  }
}
