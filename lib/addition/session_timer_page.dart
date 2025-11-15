import 'package:flutter/material.dart';
import 'dart:async';

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
    final elapsedSeconds = _stopwatch.elapsed.inSeconds;
    final bool hasProgress = elapsedSeconds > 0;

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
          'Session Timer',
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
            // Target Display Card
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
                        'Min Sessions',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.targetMin is num ? (widget.targetMin as num).toStringAsFixed(0) : "N/A",
                        style: TextStyle(
                          fontSize: 24,
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
                        'Max Sessions',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.targetMax is num ? (widget.targetMax as num).toStringAsFixed(0) : "N/A",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Timer Display Card
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
                    'Session Duration',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _formatDuration(elapsedSeconds),
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Control Buttons
            if (!_isRunning && !hasProgress)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _toggleTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Start Session',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_isRunning)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _toggleTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stop, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Stop Session',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (!_isRunning && hasProgress)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _resetTimer,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey.shade300!),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh, size: 20, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              const Text(
                                'Reset',
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
                        child: ElevatedButton(
                          onPressed: _showSaveOrDiscardDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text(
                      'Exit Without Saving',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}