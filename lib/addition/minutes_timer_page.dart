import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class MinutesTimerPage extends StatefulWidget {
  final String habitId;
  final dynamic targetMin;
  final dynamic targetMax;

  const MinutesTimerPage({
    super.key,
    required this.habitId,
    required this.targetMin,
    required this.targetMax,
  });

  @override
  State<MinutesTimerPage> createState() => _MinutesTimerPageState();
}

class _MinutesTimerPageState extends State<MinutesTimerPage> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  int _inactiveSeconds = 0;
  bool _isRunning = false;
  double _lastSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
  }

  void _startTimer() async {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final pos = await Geolocator.getCurrentPosition();
      final speed = pos.speed; // m/s
      _lastSpeed = speed;

      setState(() {
        _elapsedSeconds++;
        if (speed == 0.0) {
          _inactiveSeconds++;
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _saveAndExit() {
    final validSeconds = _elapsedSeconds - _inactiveSeconds;
    Navigator.pop(context, validSeconds);
  }

  void _discardAndExit() {
    Navigator.pop(context, null);
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }


  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedElapsed = _formatDuration(_elapsedSeconds);
    final formattedTargetMin = _formatDuration(widget.targetMin * 60);
    final formattedTargetMax = _formatDuration(widget.targetMax * 60);

    return Scaffold(
      appBar: AppBar(title: const Text('Minutes Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Min: $formattedTargetMin   Max: $formattedTargetMax'),
            const SizedBox(height: 24),
            Text('Elapsed Time', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(formattedElapsed, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Inactive Time: $_inactiveSeconds s'),
            Text('Speed: ${_lastSpeed.toStringAsFixed(2)} m/s'),
            const SizedBox(height: 24),
            if (!_isRunning)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Timer'),
                onPressed: _startTimer,
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text('Stop Timer'),
                onPressed: _stopTimer,
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _saveAndExit,
                  child: const Text('Save'),
                ),
                TextButton(
                  onPressed: _discardAndExit,
                  child: const Text('Discard'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
