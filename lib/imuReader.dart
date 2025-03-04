import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class Imureader {
  // StreamSubscription for accelerometer, gyroscope, and magnetometer
  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
  late StreamSubscription<GyroscopeEvent> _gyroscopeSubscription;
  late StreamSubscription<MagnetometerEvent> _magnetometerSubscription;

  // Variables to store sensor data
  double ax = 0.0, ay = 0.0, az = 0.0;  // Accelerometer data
  double gx = 0.0, gy = 0.0, gz = 0.0;  // Gyroscope data
  double mx = 0.0, my = 0.0, mz = 0.0;  // Magnetometer data

  // Floor detection parameters
  double lastAz = 0.0;
  int floorLevel = 0; // Initial floor level

  // Constructor: Initialize subscriptions with empty streams
  Imureader() {
    _accelerometerSubscription = Stream<AccelerometerEvent>.empty().listen((_) {});
    _gyroscopeSubscription = Stream<GyroscopeEvent>.empty().listen((_) {});
    _magnetometerSubscription = Stream<MagnetometerEvent>.empty().listen((_) {});
  }

  // Function to start reading IMU data
  void startReading() {
    stopReading(); // Prevent multiple subscriptions

    _accelerometerSubscription = accelerometerEventStream()
        .cast<AccelerometerEvent>()
        .listen((AccelerometerEvent event) {
      ax = event.x;
      ay = event.y;
      az = event.z;
      detectFloorChange();
      print("Accelerometer: ax: $ax, ay: $ay, az: $az");
    });

    _gyroscopeSubscription = gyroscopeEventStream()
        .cast<GyroscopeEvent>()
        .listen((GyroscopeEvent event) {
      gx = event.x;
      gy = event.y;
      gz = event.z;
      print("Gyroscope: gx: $gx, gy: $gy, gz: $gz");
    });

    _magnetometerSubscription = magnetometerEventStream()
        .cast<MagnetometerEvent>()
        .listen((MagnetometerEvent event) {
      mx = event.x;
      my = event.y;
      mz = event.z;
      print("Magnetometer: mx: $mx, my: $my, mz: $mz");
    });
  }

  // Function to stop reading IMU data
  void stopReading() {
    _accelerometerSubscription.cancel();
    _gyroscopeSubscription.cancel();
    _magnetometerSubscription.cancel();
  }

  // Function to get the current IMU data
  Map<String, dynamic> getImuData() {
    return {
      'accelerometer': {'x': ax, 'y': ay, 'z': az},
      'gyroscope': {'x': gx, 'y': gy, 'z': gz},
      'magnetometer': {'x': mx, 'y': my, 'z': mz},
      'floor': floorLevel,
    };
  }

  // Accumulating changes for gradual stair climb detection
  static double accumulatedChangeUp = 0.0; // For gradual upward change
  static double accumulatedChangeDown = 0.0; // For gradual downward change
  static DateTime lastChangeTime = DateTime.now();

int detectFloorChange() {
  double threshold = 0.3; // Base threshold for small changes (suitable for stair climbing)
  double significantThreshold = 2.0; // Threshold for larger floor transitions
  double rapidThreshold = 3.0; // Rapid transition threshold (e.g., 2+ floors in 1 second)

  double change = az - lastAz; // Calculate the change in Z-axis acceleration
  lastAz = az; // Update the last azimuth for the next iteration

  

  DateTime currentTime = DateTime.now();
  Duration elapsed = currentTime.difference(lastChangeTime);

  // If the elapsed time is within a small window (e.g., 3 seconds), accumulate the change
  if (elapsed.inSeconds < 3) {
    if (change.abs() > threshold) {
      if (change > 0) {
        accumulatedChangeUp += change; // Accumulate upward change
      } else {
        accumulatedChangeDown += change.abs(); // Accumulate downward change (as positive value)
      }
    }
  } else {
    // Reset the accumulation every few seconds (e.g., after 3 seconds)
    accumulatedChangeUp = 0.0;
    accumulatedChangeDown = 0.0;
  }

  // If accumulated upward change is large enough, increment the floor level
  if (accumulatedChangeUp > significantThreshold) {
    floorLevel += 1; // Increment the floor level for the gradual upward movement
    accumulatedChangeUp = 0.0; // Reset accumulated upward change
    lastChangeTime = currentTime; // Update the last change time
    return 1; // Return 1 for upward movement
  }

  // If accumulated downward change is large enough, decrement the floor level
  if (accumulatedChangeDown > significantThreshold) {
    floorLevel -= 1; // Decrement the floor level for the gradual downward movement
    accumulatedChangeDown = 0.0; // Reset accumulated downward change
    lastChangeTime = currentTime; // Update the last change time
    return -1; // Return -1 for downward movement
  }

  // Rapid floor transition (e.g., 2+ floors up or down)
  if (change.abs() > rapidThreshold) {
    if (change > 0) {
      floorLevel += 2; // Rapid upward transition (likely skipping multiple floors)
      return 2; // Indicate a rapid floor transition upwards
    } else {
      floorLevel -= 2; // Rapid downward transition (likely skipping multiple floors)
      return -2; // Indicate a rapid floor transition downwards
    }
  }

  // Significant floor transition (single floor change)
  if (change.abs() > significantThreshold) {
    if (change > 0) {
      floorLevel += 1; // Moving up a single floor
      return 1; // Indicate upward movement
    } else {
      floorLevel -= 1; // Moving down a single floor
      return -1; // Indicate downward movement
    }
  }

  // No significant change detected (remain on the current floor)
  return 0; // No floor change detected
}

}