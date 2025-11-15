import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart'; // For Cupertino icons if desired

class MinutesTimerPage extends StatefulWidget {
  final String habitId;
  final double targetMin;
  final double targetMax;

  const MinutesTimerPage({
    super.key,
    required this.habitId,
    required this.targetMin,
    required this.targetMax,
  });

  @override
  State<MinutesTimerPage> createState() => _MinutesTimerPageState();
}

class _MinutesTimerPageState extends State<MinutesTimerPage> with WidgetsBindingObserver {
  Timer? _mainTimer;
  int _totalElapsedSeconds = 0;
  int _currentLapSeconds = 0;

  int _inactiveSeconds = 0; // Seconds counted when speed is out of range
  bool _isRunning = false;
  StreamSubscription<Position>? _positionStream;
  double _lastValidSpeed = 0.0; // Speed when not inactive
  bool _shownVehicleWarning = false;
  bool _isPausedDueToSpeed = false; // Track if timer logic is "paused" due to speed

  List<int> _lapTimesInSeconds = []; // Stores duration of each completed lap
  int _lapCounter = 0;

  // --- Lifecycle & Permissions ---
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mainTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_isRunning) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Consider pausing the timer or handling background activity
      // For simplicity, we'll just let it run, but this is where you'd add more robust handling
    } else if (state == AppLifecycleState.resumed) {
      // Potentially re-check permissions or refresh UI elements
    }
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location services are disabled. Please enable them.')));
      }
      // Optionally, guide user to settings: await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')));
        }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Location permission permanently denied. Please enable in settings.')));
      }
      // Optionally: await Geolocator.openAppSettings();
      return;
    }
    // If permission granted, we can proceed.
  }

  // --- Timer Logic ---
  void _startStopTimer() {
    if (_isRunning) {
      _mainTimer?.cancel();
      _positionStream?.cancel();
    } else {
      // Reset shown vehicle warning for new session
      _shownVehicleWarning = false;

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation, // Higher accuracy
          distanceFilter: 0, // Report all changes
        ),
      ).listen((Position position) {
        if (!mounted) return;
        final currentSpeed = position.speed; // m/s

        // Speed-based pausing logic
        if (currentSpeed < 0.5 || currentSpeed > 10.0) { // Example: walking/jogging range 0.5 m/s to 10 m/s
          if (!_isPausedDueToSpeed) {
            setState(() {
              _isPausedDueToSpeed = true;
            });
          }
          if (currentSpeed > 10.0 && !_shownVehicleWarning) { // Vehicle speed threshold
            _shownVehicleWarning = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ High speed detected! Are you in a vehicle? Timer paused.'),
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          if (_isPausedDueToSpeed) {
            setState(() {
              _isPausedDueToSpeed = false;
            });
          }
          _lastValidSpeed = currentSpeed; // Update last valid speed only when within range
        }
      }, onError: (error) {
        print("Error in position stream: $error");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Location stream error: $error')));
        }
      });

      _mainTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (!_isPausedDueToSpeed) { // Only increment timers if not "paused" by speed
          setState(() {
            _totalElapsedSeconds++;
            _currentLapSeconds++;
          });
        } else {
          setState(() { // Still update UI to show inactive seconds incrementing
            _inactiveSeconds++;
          });
        }
      });
    }
    setState(() {
      _isRunning = !_isRunning;
      if (!_isRunning && _currentLapSeconds > 0) { // If stopping and there's an unfinished lap
        _recordLap(isFinalLap: true); // Record the current lap as the final one
      }
      if (_isRunning && _lapCounter == 0) { // Automatically start first lap
        _lapCounter = 1;
      }
    });
  }

  void _recordLap({bool isFinalLap = false}) {
    if (_currentLapSeconds > 0) { // Only record if lap has time
      setState(() {
        _lapTimesInSeconds.add(_currentLapSeconds);
        _currentLapSeconds = 0;
        if (!isFinalLap) { // Don't increment lap counter if it's the final stop
          _lapCounter++;
        }
      });
    }
  }

  // --- Data & Navigation ---
  void _saveAndExit() {
    _startStopTimer(); // Ensure timer is stopped and final lap recorded if running
    final validSeconds = _totalElapsedSeconds - _inactiveSeconds;
    Navigator.pop(context, validSeconds > 0 ? validSeconds : 0); // Return 0 if no valid time
  }

  void _showDiscardDialog() {
    if (_totalElapsedSeconds == 0 && _lapTimesInSeconds.isEmpty) {
      Navigator.pop(context, null); // No progress, just pop
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Discard Progress?'),
          content: const Text('Are you sure you want to discard this session and all recorded laps?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Discard'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.pop(context, null); // Pop page, discard data
              },
            ),
          ],
        );
      },
    );
  }

  // --- UI Formatting ---
  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final bool canRecordLap = _isRunning && !_isPausedDueToSpeed && _currentLapSeconds > 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[900]),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: Text(
          'Activity Timer',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Target Time Display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'Min Target',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration((widget.targetMin * 60).toInt()),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.grey.shade300,
                  ),
                  Column(
                    children: [
                      Text(
                        'Max Target',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration((widget.targetMax * 60).toInt()),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Main Timer Display
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Total Time',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _formatDuration(_totalElapsedSeconds),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Speed: ${_lastValidSpeed.toStringAsFixed(1)} m/s',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Inactive: ${_formatDuration(_inactiveSeconds)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isPausedDueToSpeed) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pause_circle_outline, size: 16, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Timer paused due to speed',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Lap Info & Controls
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LAP $_lapCounter',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration(_currentLapSeconds),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: canRecordLap ? _recordLap : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag,
                          size: 18,
                          color: canRecordLap ? Colors.white : Colors.grey[400],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Lap',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: canRecordLap ? Colors.white : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Lap List
            if (_lapTimesInSeconds.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Completed Laps',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(_lapTimesInSeconds.reversed.toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final lapTime = entry.value;
                      final lapNumber = _lapTimesInSeconds.length - index;
                      return Container(
                        margin: EdgeInsets.only(bottom: index < _lapTimesInSeconds.length - 1 ? 8 : 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Lap $lapNumber',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[900],
                              ),
                            ),
                            Text(
                              _formatDuration(lapTime),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      );
                    })),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _showDiscardDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red.shade300!),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_outlined, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Discard',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _startStopTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning ? Colors.red[600] : Colors.blue[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isRunning ? Icons.stop : Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRunning ? 'Stop' : 'Start',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_totalElapsedSeconds > 0 || _lapTimesInSeconds.isNotEmpty) ? _saveAndExit : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      side: BorderSide(color: Colors.blue.shade300!),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}