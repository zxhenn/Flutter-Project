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
    final theme = Theme.of(context);
    // In the build method, for the canRecordLap condition:
    final bool canRecordLap = _isTracking &&
        !_isPausedDueToSpeed &&
        (_lapStopwatch.elapsed.inSeconds > 0 || _currentLapDistanceKm > 0.001); // CORRECTED HERE

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Run Tracker'),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Target Display ---
            _buildTargetDisplayCard(theme),
            const SizedBox(height: 15),

            // --- Main Stats Card (Distance, Time, Speed) ---
            _buildMainStatsCard(theme),
            if (_isPausedDueToSpeed)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Tracking paused (low speed / vehicle)', style: TextStyle(color: Colors.orange[700], fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 15),


            // --- Current Lap Info & Lap Button ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LAP $_currentLapNumber', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          '${_currentLapDistanceKm.toStringAsFixed(2)} km',
                          style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.secondary),
                        ),
                        Text(
                          _formatDuration(_lapStopwatch.elapsed.inSeconds),
                          style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: Icon(Icons.flag_circle_outlined, color: canRecordLap ? Colors.white : Colors.grey[400]),
                      label: Text('Lap', style: TextStyle(color: canRecordLap ? Colors.white : Colors.grey[400])),
                      onPressed: canRecordLap ? _recordLap : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: canRecordLap ? theme.colorScheme.secondary : Colors.grey[300],
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(),

            // --- Lap List ---
            Text('Completed Laps', style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey[600])),
            Expanded(
              child: _completedLaps.isEmpty
                  ? Center(child: Text('No laps recorded yet.', style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                itemCount: _completedLaps.length,
                itemBuilder: (context, index) {
                  final lapData = _completedLaps.reversed.toList()[index]; // Newest first
                  final lapNumber = _completedLaps.length - index;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 1,
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                          child: Text('$lapNumber', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold))),
                      title: Text('${lapData.distanceKm.toStringAsFixed(2)} km', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      trailing: Text(_formatDuration(lapData.timeSeconds), style: theme.textTheme.bodyMedium),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            const SizedBox(height: 10),

            // --- Action Buttons ---
            _buildActionButtons(theme),
          ],
        ),
      ),
    );
  }

  // --- UI Helper Widgets ---
  Widget _buildTargetDisplayCard(ThemeData theme) {
    String targetDisplay = "N/A";
    if (widget.unit.toLowerCase() == 'distance (km)' && widget.target is num) {
      targetDisplay = "${(widget.target as num).toStringAsFixed(1)} km";
    } else if (widget.target is String) {
      targetDisplay = widget.target;
    }

    return Card(
      elevation: 0,
      color: Colors.transparent,
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.track_changes_outlined, color: Colors.grey[600], size: 18),
            const SizedBox(width: 8),
            Text('Target: ', style: theme.textTheme.labelLarge?.copyWith(color: Colors.grey[700])),
            Text(targetDisplay, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainStatsCard(ThemeData theme) {
    return Card(
      elevation: 4,
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Distance', style: theme.textTheme.titleSmall),
                    Text(
                      '${_totalDistanceKm.toStringAsFixed(2)} km',
                      style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                SizedBox(
                    height: 50,
                    child: VerticalDivider(color: Colors.grey[400])),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Time', style: theme.textTheme.titleSmall),
                    Text(
                      _formatDuration(_mainStopwatch.elapsed.inSeconds),
                      style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Speed: ${_currentSpeedKmh.toStringAsFixed(1)} km/h', style: theme.textTheme.bodySmall),
                Text('Inactive: ${_formatDuration(_totalInactiveSeconds)}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange[800])),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Discard'),
            onPressed: _showDiscardDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[700],
              side: BorderSide(color: Colors.red[300]!),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          ElevatedButton.icon(
            icon: _isTracking ? const Icon(CupertinoIcons.stop_fill) : const Icon(CupertinoIcons.play_arrow_solid),
            label: Text(_isTracking ? 'Stop' : 'Start', style: TextStyle(fontSize: 16)),
            onPressed: _toggleTracking,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTracking ? Colors.redAccent : theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.save_alt_outlined),
            label: const Text('Save'),
            onPressed: (_totalDistanceKm > 0 || _completedLaps.isNotEmpty) ? _saveAndExit : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}