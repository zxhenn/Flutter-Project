import 'package:flutter/material.dart';
import 'dart:async';

class SessionTimerPage extends StatefulWidget {
  final String habitId;
  final dynamic targetMin;
  final dynamic targetMax;


  const SessionTimerPage({
    super.key,
    required this.habitId,
    required this.targetMin,
    required this.targetMax,

  });

  @override
  State<SessionTimerPage> createState() => _SessionTimerPageState();
}

class _SessionTimerPageState extends State<SessionTimerPage> {
  Stopwatch stopwatch = Stopwatch();
  late Timer timer;
  String elapsed = '0:00';
  bool isRunning = false;
  bool isStopped = false;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => updateDisplay());
  }

  void updateDisplay() {
    if (stopwatch.isRunning) {
      final minutes = stopwatch.elapsed.inMinutes;
      final seconds = stopwatch.elapsed.inSeconds % 60;
      setState(() => elapsed = '$minutes:${seconds.toString().padLeft(2, '0')}');
    }
  }

  void startTimer() {
    setState(() {
      stopwatch.start();
      isRunning = true;
      isStopped = false;
    });
  }

  void stopTimer() {
    setState(() {
      stopwatch.stop();
      isRunning = false;
      isStopped = true;
    });
  }

  void _showSaveDialog() {
    final int durationInSeconds = stopwatch.elapsed.inSeconds;

    if (durationInSeconds < 60) {
      // Auto-discard too short sessions
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session must last at least 1 minute to count.')),
      );
      Navigator.pop(context); // Discard and return
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save Session?'),
        content: Text('You spent ${durationInSeconds ~/ 60} min ${durationInSeconds % 60} sec. Save this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, {
                'sessionCount': 1,
                'duration': durationInSeconds,
              }); // ✅ Send back both count and duration
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }


  @override
  void dispose() {
    timer.cancel();
    stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Session')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              elapsed,
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            if (!isRunning && !isStopped)
              ElevatedButton.icon(
                onPressed: startTimer,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Session'),
              )
            else if (isRunning)
              ElevatedButton.icon(
                onPressed: stopTimer,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              )
            else if (isStopped)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _showSaveDialog,
                      child: const Text('Save Session'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      child: const Text('Discard'),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
