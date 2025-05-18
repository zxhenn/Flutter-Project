// minutes_timer_page.dart
import 'package:flutter/material.dart';
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
  bool _isRunning = false;

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _elapsedSeconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _saveAndExit() {
    Navigator.pop(context, _elapsedSeconds);
  }

  void _discardAndExit() {
    Navigator.pop(context, null);
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
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
    final formattedTargetMin = _formatDuration(widget.targetMin);
    final formattedTargetMax = _formatDuration(widget.targetMax);

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