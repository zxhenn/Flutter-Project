import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class GPSRunningTrackerPage extends StatefulWidget {
  final String habitId;
  final dynamic target;
  final String unit;


  const GPSRunningTrackerPage({
    super.key,
    required this.habitId,
    required this.target,
    required this.unit,
  });

  @override
  State<GPSRunningTrackerPage> createState() => _GPSRunningTrackerPageState();
}

class _GPSRunningTrackerPageState extends State<GPSRunningTrackerPage> {
  Stopwatch stopwatch = Stopwatch();
  Timer? updateTimer;
  Position? _lastPosition;
  double _totalDistance = 0.0;
  double _speed = 0.0;
  bool _isTracking = false;
  String elapsed = '0:00';

  @override
  void dispose() {
    updateTimer?.cancel();
    stopwatch.stop();
    super.dispose();
  }

  void startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        return;
      }
    }

    _lastPosition = await Geolocator.getCurrentPosition();
    stopwatch.start();
    setState(() => _isTracking = true);

    updateTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final newPos = await Geolocator.getCurrentPosition();
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        newPos.latitude,
        newPos.longitude,
      );
      setState(() {
        _totalDistance += distance / 1000; // meters to km
        _speed = newPos.speed * 3.6; // m/s to km/h
        _lastPosition = newPos;
        final minutes = stopwatch.elapsed.inMinutes;
        final seconds = stopwatch.elapsed.inSeconds % 60;
        elapsed = '$minutes:${seconds.toString().padLeft(2, '0')}';
      });
    });
  }

  void stopAndSave() {
    stopwatch.stop();
    updateTimer?.cancel();
    Navigator.pop(context, _totalDistance);
  }

  void cancelTracking() {
    updateTimer?.cancel();
    stopwatch.stop();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Running Tracker'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${_totalDistance.toStringAsFixed(2)} km',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Speed: ${_speed.toStringAsFixed(1)} km/h'),
            Text('Time: $elapsed'),
            const SizedBox(height: 30),
            !_isTracking
                ? ElevatedButton.icon(
              onPressed: startTracking,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Tracking'),
            )
                : ElevatedButton.icon(
              onPressed: stopAndSave,
              icon: const Icon(Icons.stop),
              label: const Text('Stop and Save'),
            ),
          ],
        ),
      ),
    );
  }
}
