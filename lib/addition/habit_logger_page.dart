import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

class HabitLoggerPage extends StatefulWidget {
  final String habitId;
  final Map<String, dynamic> habitData;

  const HabitLoggerPage({
    super.key,
    required this.habitId,
    required this.habitData,
  });

  @override
  State<HabitLoggerPage> createState() => _HabitLoggerPageState();
}

class _HabitLoggerPageState extends State<HabitLoggerPage> {
  late double todayProgress;
  late int todayExcess;
  late double targetMin;
  late double targetMax;
  late String type;
  late String unit;
  bool isComplete = false;

  @override
  void initState() {
    super.initState();
    todayProgress = (widget.habitData['todayProgress'] ?? 0).toDouble();
    todayExcess = widget.habitData['todayExcess'] ?? 0;
    targetMin = (widget.habitData['targetMin'] ?? 1).toDouble();
    targetMax = (widget.habitData['targetMax'] ?? 1).toDouble();
    type = widget.habitData['type'] ?? 'Habit';
    unit = widget.habitData['unit'] ?? 'units';
    isComplete = todayProgress >= targetMin;
  }

  Future<void> _incrementProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (todayProgress < targetMax) {
        todayProgress += 1;
      } else {
        todayExcess += 1;
      }
      isComplete = todayProgress >= targetMin;
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('habits')
        .doc(widget.habitId)
        .update({
      'todayProgress': unit == 'Sessions' ? todayProgress.toInt() : todayProgress,
      'todayExcess': todayExcess,
    });
  }

  bool isGPSAllowed() {
    final t = type.toLowerCase();
    return (t.contains('run') || t.contains('walk')) &&
        (unit == 'Minutes' || unit == 'Distance (km)');
  }

  bool isManualTapAllowed() {
    return unit != 'Distance (km)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Progress'),
        backgroundColor: Colors.blue[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$type ($unit)', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (todayProgress / targetMax).clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.grey[300],
              color: isComplete ? Colors.green : Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(height: 12),
            Text('${todayProgress.toStringAsFixed(2)} / $targetMax $unit'),
            if (todayExcess > 0)
              Text('+$todayExcess excess', style: const TextStyle(color: Colors.orange)),
            const SizedBox(height: 32),

            if (isManualTapAllowed())
              ElevatedButton(
                onPressed: _incrementProgress,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('+1', style: TextStyle(fontSize: 24, color: Colors.white)),
              ),

            if (isGPSAllowed()) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GPSRunningTrackerPage(
                        habitId: widget.habitId,
                        targetMin: targetMin,
                        targetMax: targetMax,
                        unit: unit,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.location_on, color: Colors.white),
                label: const Text('Track Automatically', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            const SizedBox(height: 16),
            if (isComplete)
              Text(
                todayProgress >= targetMax
                    ? '🎉 You reached your goal for today, take a rest!'
                    : '👍 Minimum Reached',
                style: TextStyle(
                  color: todayProgress >= targetMax ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),

          ],
        ),
      ),
    );
  }
}

class GPSRunningTrackerPage extends StatefulWidget {
  final String habitId;
  final double targetMin;
  final double targetMax;
  final String unit;

  const GPSRunningTrackerPage({
    super.key,
    required this.habitId,
    required this.targetMin,
    required this.targetMax,
    required this.unit,
  });

  @override
  State<GPSRunningTrackerPage> createState() => _GPSRunningTrackerPageState();
}

class _GPSRunningTrackerPageState extends State<GPSRunningTrackerPage> with SingleTickerProviderStateMixin {
  Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  List<Position> _positions = [];
  double _distance = 0.0;
  double _currentSpeed = 0.0;
  bool _tracking = false;

  late AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    _startTracking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lottieController.dispose();
    super.dispose();
  }

  Future<void> _startTracking() async {
    final granted = await _checkPermissions();
    if (!granted) return;

    _positions.clear();
    _distance = 0.0;
    _stopwatch.reset();
    _stopwatch.start();
    _tracking = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen((Position position) {
      setState(() {
        _currentSpeed = position.speed * 3.6;
        if (_positions.isNotEmpty) {
          _distance += Geolocator.distanceBetween(
            _positions.last.latitude,
            _positions.last.longitude,
            position.latitude,
            position.longitude,
          );
        }
        _positions.add(position);
      });
    });
  }

  Future<void> _stopTracking() async {
    _stopwatch.stop();
    _timer?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    double addValue = 0.0;
    if (widget.unit == 'Minutes') {
      addValue = _stopwatch.elapsed.inMinutes.toDouble();
    } else if (widget.unit == 'Distance (km)') {
      addValue = _distance / 1000;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('habits')
        .doc(widget.habitId)
        .update({
      'todayProgress': FieldValue.increment(addValue),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tracked +${addValue.toStringAsFixed(2)} ${widget.unit}')),
    );
    Navigator.pop(context);
  }

  Future<bool> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  @override
  Widget build(BuildContext context) {
    final km = _distance / 1000;
    final isRunning = _currentSpeed > 1.0;
    final progress = (widget.unit == 'Distance (km)')
        ? (km / widget.targetMax).clamp(0.0, 1.0)
        : (_stopwatch.elapsed.inMinutes / widget.targetMax).clamp(0.0, 1.0);
    final milestone = (widget.targetMin / widget.targetMax).clamp(0.0, 1.0);

    // animation logic
    if (isRunning) {
      _lottieController.repeat();
    } else {
      _lottieController.stop();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: Lottie.asset(
                'assets/animations/running.json',
                controller: _lottieController,
                onLoaded: (composition) {
                  _lottieController.duration = composition.duration;
                  if (isRunning) {
                    _lottieController.repeat();
                  } else {
                    _lottieController.stop();
                  }
                },
              ),
            ),
            Text(
              widget.unit == 'Distance (km)'
                  ? 'Distance: ${km.toStringAsFixed(2)} km'
                  : 'Time: ${_stopwatch.elapsed.inMinutes} min',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Stack(
              children: [
                Container(height: 20, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: progress >= milestone ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Positioned(
                  left: MediaQuery.of(context).size.width * milestone - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text('Speed: ${_currentSpeed.toStringAsFixed(1)} km/h'),
            const SizedBox(height: 20),
            if (!_tracking)
              ElevatedButton(onPressed: _startTracking, child: const Text('Start Tracking')),
            if (_tracking)
              ElevatedButton(onPressed: _stopTracking, child: const Text('Stop & Save')),
          ],
        ),
      ),
    );
  }
}
