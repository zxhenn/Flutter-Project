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
    final theme = Theme.of(context);
    final bool canRecordLap = _isRunning && !_isPausedDueToSpeed && _currentLapSeconds > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Timer'),
        elevation: 1,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.textTheme.titleLarge?.color,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Target Time Display ---
            _buildTargetTimeCard(theme),
            const SizedBox(height: 20),

            // --- Main Timer Display ---
            _buildMainTimerCard(theme),
            const SizedBox(height: 12),
            if (_isPausedDueToSpeed)
              Text('Timer paused due to speed', style: TextStyle(color: Colors.orange[700], fontStyle: FontStyle.italic)),
            const SizedBox(height: 20),


            // --- Lap Info & Controls ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LAP $_lapCounter', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(_formatDuration(_currentLapSeconds), style: theme.textTheme.headlineSmall),
                  ],
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.flag_outlined, color: canRecordLap ? null : Colors.grey),
                  label: const Text('Lap'),
                  onPressed: canRecordLap ? _recordLap : null,
                  style: ElevatedButton.styleFrom(
                    // backgroundColor: theme.colorScheme.secondary,
                    // foregroundColor: theme.colorScheme.onSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(),

            // --- Lap List ---
            Expanded(
              child: _lapTimesInSeconds.isEmpty
                  ? Center(child: Text('No laps recorded yet.', style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                itemCount: _lapTimesInSeconds.length,
                itemBuilder: (context, index) {
                  final lapTime = _lapTimesInSeconds.reversed.toList()[index]; // Show newest first
                  final lapNumber = _lapTimesInSeconds.length - index;
                  return ListTile(
                    dense: true,
                    leading: Text('Lap $lapNumber', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    trailing: Text(_formatDuration(lapTime), style: theme.textTheme.bodyMedium),
                  );
                },
              ),
            ),
            Divider(),
            const SizedBox(height: 10),

            // --- Action Buttons ---
            _buildActionButtons(theme),
          ],
        ),
      ),
    );
  }

  // --- UI Helper Widgets ---
  Widget _buildTargetTimeCard(ThemeData theme) {
    final formattedTargetMin = _formatDuration((widget.targetMin * 60).toInt());
    final formattedTargetMax = _formatDuration((widget.targetMax * 60).toInt());
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text('Min Target', style: theme.textTheme.labelLarge?.copyWith(color: Colors.grey[700])),
                Text(formattedTargetMin, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            Column(
              children: [
                Text('Max Target', style: theme.textTheme.labelLarge?.copyWith(color: Colors.grey[700])),
                Text(formattedTargetMax, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainTimerCard(ThemeData theme) {
    return Card(
      elevation: 4,
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Column(
          children: [
            Text('Total Time', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _formatDuration(_totalElapsedSeconds),
              style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Speed: ${_lastValidSpeed.toStringAsFixed(1)} m/s', style: theme.textTheme.bodySmall),
                Text('Inactive: ${_formatDuration(_inactiveSeconds)}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange[800])),
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
            icon: _isRunning ? const Icon(Icons.stop_rounded) : const Icon(Icons.play_arrow_rounded),
            label: Text(_isRunning ? 'Stop' : 'Start', style: TextStyle(fontSize: 16)),
            onPressed: _startStopTimer,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRunning ? Colors.redAccent : theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.save_alt_outlined),
            label: const Text('Save'),
            onPressed: (_totalElapsedSeconds > 0 || _lapTimesInSeconds.isNotEmpty) ? _saveAndExit : null, // Disable if no progress
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