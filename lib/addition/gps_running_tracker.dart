import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart'; // For Cupertino icons if desired

// Helper class for Lap Data
class LapData {
  final double distanceKm;
  final int timeSeconds;

  LapData({required this.distanceKm, required this.timeSeconds});
}

class GPSRunningTrackerPage extends StatefulWidget {
  final String habitId;
  final dynamic target; // Could be distance (e.g., 5.0 for 5km)
  final String unit;   // Should be 'distance (km)' for this tracker

  const GPSRunningTrackerPage({
    super.key,
    required this.habitId,
    required this.target,
    required this.unit, // Ensure this is 'distance (km)'
  });

  @override
  State<GPSRunningTrackerPage> createState() => _GPSRunningTrackerPageState();
}

class _GPSRunningTrackerPageState extends State<GPSRunningTrackerPage> with WidgetsBindingObserver {
  // --- Main Tracking State ---
  Stopwatch _mainStopwatch = Stopwatch();
  Timer? _uiUpdateTimer; // For updating UI every second (time display)
  StreamSubscription<Position>? _positionStreamSubscription;

  bool _isTracking = false;
  Position? _lastPosition;
  double _totalDistanceKm = 0.0;
  double _currentSpeedKmh = 0.0;
  bool _isPausedDueToSpeed = false; // If speed is too low to be considered "active"
  int _totalInactiveSeconds = 0; // Time spent while _isPausedDueToSpeed is true

  // --- Lap Tracking State ---
  Stopwatch _lapStopwatch = Stopwatch();
  double _currentLapDistanceKm = 0.0;
  int _currentLapNumber = 0;
  List<LapData> _completedLaps = [];

  // --- Lifecycle & Permissions ---
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndRequestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiUpdateTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _mainStopwatch.stop();
    _lapStopwatch.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_isTracking) return;
    // Handle app pausing/resuming if needed (more complex for GPS)
  }

  Future<void> _checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location services are disabled. Please enable them.')));
      }
      // Consider Geolocator.openLocationSettings();
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
      // Consider Geolocator.openAppSettings();
      return;
    }
    // Permission granted
  }

  // --- Tracking Logic ---
  void _toggleTracking() async {
    if (_isTracking) { // ---- STOPPING ----
      _uiUpdateTimer?.cancel();
      _positionStreamSubscription?.cancel();
      _mainStopwatch.stop();
      _lapStopwatch.stop();

      if (_currentLapDistanceKm > 0.001 || _lapStopwatch.elapsed.inSeconds > 0) { // CORRECTED HERE
        _recordLap(isFinalLap: true); // Record the final lap
      }
    } else { // ---- STARTING ----
      // Reset state for a new session
      setState(() {
        _totalDistanceKm = 0.0;
        _mainStopwatch.reset();
        _currentLapDistanceKm = 0.0;
        _lapStopwatch.reset();
        _completedLaps.clear();
        _currentLapNumber = 1; // Start with Lap 1
        _currentSpeedKmh = 0.0;
        _lastPosition = null;
        _isPausedDueToSpeed = false;
        _totalInactiveSeconds = 0;
      });

      // Ensure permissions are still good
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission issue. Please check settings.')));
        return;
      }

      try {
        _lastPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get initial location: $e')));
        return;
      }

      _mainStopwatch.start();
      _lapStopwatch.start();

      // UI Timer (for stopwatch display)
      _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_isPausedDueToSpeed) {
          setState(() {
            _totalInactiveSeconds++;
          });
        }
        setState(() {}); // Update UI for time
      });

      // Position Stream
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5, // Update every 5 meters to reduce calculations
        ),
      ).listen((Position newPosition) {
        if (!mounted || _lastPosition == null) return;

        final double speedMs = newPosition.speed; // m/s
        final double speedKmh = speedMs * 3.6;

        // Speed-based activity detection
        // Adjust these thresholds: e.g., 2 km/h (0.55 m/s) for walking, 20 km/h for running cutoff
        if (speedKmh < 2.0 || speedKmh > 30.0) { // Example thresholds
          if (!_isPausedDueToSpeed) {
            setState(() => _isPausedDueToSpeed = true);
            if (speedKmh > 30.0) { // Vehicle detection
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('High speed! Are you in a vehicle? Tracking paused.'), duration: Duration(seconds: 3)),
              );
            }
          }
        } else {
          if (_isPausedDueToSpeed) {
            setState(() => _isPausedDueToSpeed = false);
          }
        }

        if (!_isPausedDueToSpeed) { // Only calculate distance if actively tracking
          final distanceIncrement = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            newPosition.latitude,
            newPosition.longitude,
          ); // meters

          setState(() {
            _totalDistanceKm += distanceIncrement / 1000.0;
            _currentLapDistanceKm += distanceIncrement / 1000.0;
          });
        }

        setState(() {
          _currentSpeedKmh = speedKmh; // Always update displayed speed
          _lastPosition = newPosition;
        });

      }, onError: (error) {
        print("Position Stream Error: $error");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location error: $error')));
      });
    }
    setState(() => _isTracking = !_isTracking);
  }

  void _recordLap({bool isFinalLap = false}) {
    // Use _lapStopwatch.elapsed.inSeconds for the current lap's time
    if (_lapStopwatch.elapsed.inSeconds > 0 || _currentLapDistanceKm > 0.001) { // Min duration/distance to record a lap
      setState(() {
        _completedLaps.add(LapData(
          distanceKm: _currentLapDistanceKm,
          timeSeconds: _lapStopwatch.elapsed.inSeconds, // CORRECTED HERE
        ));
        _currentLapDistanceKm = 0.0;
        _lapStopwatch.reset(); // Reset for the next lap or for stop
        if (!isFinalLap) {
          _currentLapNumber++;
          _lapStopwatch.start(); // Start stopwatch for the new lap
        }
      });
    } else if (!isFinalLap) { // Only show snackbar if not the final auto-lap on stop
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lap too short to record.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // --- Data & Navigation ---
  void _saveAndExit() {
    if (_isTracking) { // Ensure tracking is stopped before saving
      _toggleTracking(); // This will stop timers and record final lap
    }
    // Data to return: total distance covered while active
    // If you want to subtract distance covered during _isPausedDueToSpeed, that's more complex.
    // For now, _totalDistanceKm accumulates only when !_isPausedDueToSpeed.
    Navigator.pop(context, _totalDistanceKm > 0 ? _totalDistanceKm : 0.0);
  }

  void _showDiscardDialog() {
    if (_totalDistanceKm == 0 && _completedLaps.isEmpty) {
      Navigator.pop(context, null);
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Discard Session?'),
          content: const Text('Are you sure you want to discard this running session?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Discard'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pop(context, null);
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
    final bool canRecordLap = _isTracking &&
        !_isPausedDueToSpeed &&
        (_lapStopwatch.elapsed.inSeconds > 0 || _currentLapDistanceKm > 0.001);

    String targetDisplay = "N/A";
    if (widget.unit.toLowerCase() == 'distance (km)' && widget.target is num) {
      targetDisplay = "${(widget.target as num).toStringAsFixed(1)} km";
    } else if (widget.target is String) {
      targetDisplay = widget.target;
    }

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
          'GPS Run Tracker',
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
            // Target Display
            Container(
              padding: const EdgeInsets.all(16),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.track_changes_outlined, color: Colors.grey[600], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Target: ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    targetDisplay,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Main Stats Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Distance',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_totalDistanceKm.toStringAsFixed(2)} km',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: Colors.grey.shade300,
                      ),
                      Column(
                        children: [
                          Text(
                            'Time',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDuration(_mainStopwatch.elapsed.inSeconds),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                              fontFeatures: [const FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                          'Speed: ${_currentSpeedKmh.toStringAsFixed(1)} km/h',
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
                          'Inactive: ${_formatDuration(_totalInactiveSeconds)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isPausedDueToSpeed) ...[
                    const SizedBox(height: 16),
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
                            'Tracking paused (low speed / vehicle)',
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

            // Current Lap Info
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
                        'LAP $_currentLapNumber',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_currentLapDistanceKm.toStringAsFixed(2)} km',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(_lapStopwatch.elapsed.inSeconds),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
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

            // Completed Laps
            if (_completedLaps.isNotEmpty) ...[
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
                    ...(_completedLaps.reversed.toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final lapData = entry.value;
                      final lapNumber = _completedLaps.length - index;
                      return Container(
                        margin: EdgeInsets.only(bottom: index < _completedLaps.length - 1 ? 8 : 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$lapNumber',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${lapData.distanceKm.toStringAsFixed(2)} km',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[900],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _formatDuration(lapData.timeSeconds),
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
                  child: OutlinedButton.icon(
                    onPressed: _showDiscardDialog,
                    icon: Icon(Icons.cancel_outlined, size: 18),
                    label: const Text(
                      'Discard',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red.shade300!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleTracking,
                    icon: Icon(
                      _isTracking ? Icons.stop : Icons.play_arrow,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      _isTracking ? 'Stop' : 'Start',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTracking ? Colors.red[600] : Colors.blue[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_totalDistanceKm > 0 || _completedLaps.isNotEmpty) ? _saveAndExit : null,
                    icon: Icon(Icons.save, size: 18),
                    label: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      side: BorderSide(color: Colors.blue.shade300!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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