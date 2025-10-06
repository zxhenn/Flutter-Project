import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart'; // For Cupertino icons if desired

class SessionTimerPage extends StatefulWidget {
  final String habitId;
  // Assuming targetMin/Max for sessions refer to a count, not duration for individual sessions.
  // If they are duration targets for THIS session, the UI would need to adapt.
  final dynamic targetMin; // e.g., target 1 session
  final dynamic targetMax; // e.g., target 3 sessions

  const SessionTimerPage({
    super.key,
    required this.habitId,
    required this.targetMin,
    required this.targetMax,
  });

  @override
  State<SessionTimerPage> createState() => _SessionTimerPageState();
}

class _SessionTimerPageState extends State<SessionTimerPage> with WidgetsBindingObserver {
  Stopwatch _stopwatch = Stopwatch();
  Timer? _uiUpdateTimer; // For updating the UI display every second

  bool _isRunning = false;
  // bool _isStopped = false; // Can be inferred from !_isRunning && _stopwatch.elapsedMilliseconds > 0

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Timer to update the display every second, only if stopwatch is running
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_stopwatch.isRunning && mounted) {
        setState(() {
          // This setState call forces a rebuild to update the elapsed time display
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiUpdateTimer?.cancel();
    _stopwatch.stop(); // Ensure stopwatch is stopped
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle states if needed, e.g., pausing stopwatch on app pause
    // For simplicity, current logic keeps stopwatch running if started.
  }

  void _toggleTimer() {
    if (_isRunning) {
      _stopwatch.stop();
    } else {
      // If resuming a stopped session or starting new:
      if (!_stopwatch.isRunning && _stopwatch.elapsedMilliseconds > 0) {
        // This is a "Resume" scenario if we add a pause button.
        // For now, "Start" always resets or starts new.
        // If you want a reset button:
        // _stopwatch.reset();
      }
      _stopwatch.start();
    }
    setState(() {
      _isRunning = !_isRunning;
    });
  }

  void _resetTimer() {
    setState(() {
      _stopwatch.reset();
      _isRunning = false;
      // _isStopped = false; // No longer explicitly needed with current button logic
    });
  }


  void _showSaveOrDiscardDialog() {
    final int durationInSeconds = _stopwatch.elapsed.inSeconds;

    if (!_isRunning && durationInSeconds == 0) { // If stopped and no time elapsed
      Navigator.pop(context, null); // Just discard
      return;
    }

    // If running, stop it first
    if (_isRunning) {
      _stopwatch.stop();
      setState(() {
        _isRunning = false;
      });
    }

    if (durationInSeconds < 10) { // Example: Minimum 10 seconds for a session to be meaningful
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Session Too Short'),
          content: const Text('This session is very short. Do you still want to save it or discard?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _resetTimer(); // Allow user to start over or leave
              },
              child: const Text('Discard & Reset'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, {'sessionCount': 1, 'duration': durationInSeconds});
              },
              child: Text('Save Anyway (${_formatDuration(durationInSeconds)})'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Session Complete'),
        content: Text('Session duration: ${_formatDuration(durationInSeconds)}. Save this session?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _resetTimer(); // Optionally reset if they discard from here
              // Or Navigator.pop(context, null); if just exiting page
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, {'sessionCount': 1, 'duration': durationInSeconds});
            },
            child: const Text('Save Session'),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsedSeconds = _stopwatch.elapsed.inSeconds;
    final bool hasProgress = elapsedSeconds > 0;
    final bool canSave = !_isRunning && hasProgress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Timer'),
        elevation: 1,
        // backgroundColor: theme.scaffoldBackgroundColor,
        // foregroundColor: theme.textTheme.titleLarge?.color,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Pushes controls to bottom
          children: [
            Column( // Group for timer and targets
              children: [
                _buildTargetDisplay(theme),
                const SizedBox(height: 40),
                _buildTimerDisplay(theme, elapsedSeconds),
              ],
            ),
            _buildControlButtons(theme, canSave, hasProgress),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetDisplay(ThemeData theme) {
    // Assuming targetMin/Max are session counts for this habit type
    String minTargetDisplay = widget.targetMin is num ? (widget.targetMin as num).toStringAsFixed(0) : "N/A";
    String maxTargetDisplay = widget.targetMax is num ? (widget.targetMax as num).toStringAsFixed(0) : "N/A";

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
                Text('Min Sessions', style: theme.textTheme.labelLarge?.copyWith(color: Colors.grey[700])),
                Text(minTargetDisplay, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            Column(
              children: [
                Text('Max Sessions', style: theme.textTheme.labelLarge?.copyWith(color: Colors.grey[700])),
                Text(maxTargetDisplay, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerDisplay(ThemeData theme, int elapsedSeconds) {
    return Column(
      children: [
        Text(
          'Session Duration',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[800]),
        ),
        const SizedBox(height: 8),
        Text(
          _formatDuration(elapsedSeconds),
          style: theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            fontFeatures: [const FontFeature.tabularFigures()], // For stable digit width
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons(ThemeData theme, bool canSave, bool hasProgress) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0), // Add some padding from bottom edge
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isRunning && !hasProgress) // Initial state: Only show Start
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(CupertinoIcons.play_arrow_solid, size: 28),
                label: const Text('Start Session', style: TextStyle(fontSize: 18)),
                onPressed: _toggleTimer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (_isRunning) // Running state: Only show Stop
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(CupertinoIcons.stop_fill, size: 28),
                label: const Text('Stop Session', style: TextStyle(fontSize: 18)),
                onPressed: _toggleTimer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (!_isRunning && hasProgress) // Stopped with progress: Show Save & Discard/Reset
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reset'),
                    onPressed: _resetTimer,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.secondary,
                      side: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.7)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_alt_outlined),
                    label: const Text('Save'),
                    onPressed: _showSaveOrDiscardDialog, // This will handle the dialog
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          // Always show an exit button if not running, or if it's the initial state
          if (!_isRunning)
            TextButton(
              onPressed: () => Navigator.pop(context, null), // Discard and exit
              child: Text(
                hasProgress ? 'Exit Without Saving' : 'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
        ],
      ),
    );
  }
}