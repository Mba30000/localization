import 'dart:math';
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class ImuReader {
  // StreamSubscription for accelerometer
  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;

  // Variables to store sensor data
  double ax = 0.0, ay = 0.0, az = 0.0;  // Accelerometer data
  double velocity = 0.0;  // Vertical velocity (m/s)
  double height = 0.0;  // Height (m)

  // Smoothed and adjusted Z-axis data (az)
  double smoothedAz = 0.0;  
  final double alpha = 0.1;  // Low-pass filter constant for smoothing
  
  // Gravity constant (m/s^2)
  final double gravity = 9.81;  // Earth's gravitational acceleration (m/s^2)

  // Threshold for noise rejection
  final double noiseThreshold = 0.01; // Minimum acceleration change to consider

  // Constructor: Initialize subscriptions with empty streams
  ImuReader() {
    _accelerometerSubscription = Stream<AccelerometerEvent>.empty().listen((_) {});
  }

  // Function to calculate tilt angle (in radians) using accelerometer data
  double calculateTiltAngle() {
    // Tilt angle (in radians) is calculated using arctan
    double angle = atan2(ay, sqrt(ax * ax + az * az));
    return angle;  // Angle in radians
  }

  // Function to adjust vertical acceleration using tilt compensation
  double adjustVerticalAcceleration(double rawAz, double tiltAngle) {
    // Vertical acceleration is adjusted by the cosine of the tilt angle
    return rawAz * cos(tiltAngle);
  }

  // Function to detect height change based on accelerometer data
  void detectHeightChange() {
    // Subtract gravity from the raw az to get the relative vertical acceleration
    double adjustedAz = az - gravity;
    
    // Apply low-pass filter to smooth the Z-axis (az)
    smoothedAz = alpha * adjustedAz + (1 - alpha) * smoothedAz;

    // Check if the change in acceleration exceeds the noise threshold
    if (smoothedAz.abs() < noiseThreshold) {
      return; // No significant movement, ignore small noise
    }

    // Integrate acceleration to get velocity
    velocity += smoothedAz * 1;  // Assume 50 Hz sampling rate (0.02s delta time)
    
    // Integrate velocity to get height (displacement)
    height += velocity * 1;

    // Output the height change for debugging
    print("Height: $height m");

    // Reset to zero if the height starts decreasing rapidly due to noise
    if (height < 0) {
      height = 0;
      velocity = 0;
    }
  }

  // Function to start reading IMU data
  void startReading() {
    stopReading();  // Prevent multiple subscriptions

    // Subscribe to the accelerometer stream
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      ax = event.x;
      ay = event.y;
      az = event.z;
      detectHeightChange();  // Call detectHeightChange to calculate height change
    });
  }

  // Function to stop reading IMU data
  void stopReading() {
    _accelerometerSubscription.cancel();
  }

  // Function to get the current IMU data (including height)
  Map<String, dynamic> getImuData() {
    return {
      'accelerometer': {'x': ax, 'y': ay, 'z': az},
      'height': height,  // Include calculated height in data
    };
  }
}
