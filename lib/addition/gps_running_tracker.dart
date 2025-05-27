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
  bool _isDisposed = false;

  Stopwatch stopwatch = Stopwatch();
  Timer? updateTimer;
  Position? _lastPosition;
  double _totalDistance = 0.0;
  double _speed = 0.0;
  bool _isTracking = false;
  String elapsed = '0:00';

  @override
  void dispose() {
    _isDisposed = true;
    updateTimer?.cancel();
    stopwatch.stop();
    _isTracking = false;
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

    _isTracking = true;
    if (!_isDisposed) {
      setState(() {});
    }



    updateTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_isDisposed || _lastPosition == null) return;

      final newPos = await Geolocator.getCurrentPosition();

      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        newPos.latitude,
        newPos.longitude,
      );

      final minutes = stopwatch.elapsed.inMinutes;
      final seconds = stopwatch.elapsed.inSeconds % 60;

      if (_isDisposed || !mounted) return;

      final speedKmh = newPos.speed * 3.6;

      if (speedKmh >= 10.0) {
        setState(() {
          _totalDistance += distance / 1000; // only count if fast enough
          _speed = speedKmh;
          _lastPosition = newPos;
          elapsed = '$minutes:${seconds.toString().padLeft(2, '0')}';

        });

      } else {
        setState(() {
          _speed = speedKmh; // show speed, but don't count distance
          elapsed = '$minutes:${seconds.toString().padLeft(2, '0')}';
        });
      }

    });


  }

  void stopAndSave() {
    if (_isTracking) {
      updateTimer?.cancel();
      stopwatch.stop();
      _isTracking = false;
    }
    if (!mounted) return;
    Navigator.pop(context, _totalDistance);
  }

  void cancelTracking() {
    if (_isTracking) {
      updateTimer?.cancel();
      stopwatch.stop();
      _isTracking = false;
    }
    if (!mounted) return;
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
