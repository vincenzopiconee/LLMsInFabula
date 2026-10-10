import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';

// Rimosso import di voting_time_page.dart perché non navighiamo più direttamente

class DiscussionTimerWidget extends StatefulWidget {
  final String roomId;
  final String uid;
  final VoidCallback? onTimerEnd; // Callback per notificare la fine del tempo

  const DiscussionTimerWidget({
    super.key, 
    required this.roomId, 
    required this.uid,
    this.onTimerEnd,
  });

  @override
  State<DiscussionTimerWidget> createState() => _DiscussionTimerWidgetState();
}

class _DiscussionTimerWidgetState extends State<DiscussionTimerWidget> {
  late DatabaseReference _timerRef;
  Timer? _uiTicker;
  bool _timerExpiredProcessed = false; // Flag per evitare chiamate multiple

  @override
  void initState() {
    super.initState();
    _timerRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}/timer");
    
    _uiTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    if (totalSeconds < 0) return "00:00";
    final int m = totalSeconds ~/ 60;
    final int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int _safeInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _timerRef.onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return _buildBarWithText(1.0, Colors.grey, "Waiting...", Colors.black54);
        }

        final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final int startTime = _safeInt(data['startTime'], 0);
        final int durationSec = _safeInt(data['duration'], 300);

        if (startTime == 0) return _buildBarWithText(1.0, Colors.grey, "Ready...", Colors.black54);

        final int now = DateTime.now().millisecondsSinceEpoch;
        final int endTime = startTime + (durationSec * 1000);
        final int remainingMs = endTime - now;
        final int remainingSeconds = (remainingMs / 1000).ceil();

        // --- SCADENZA TEMPO ---
        if (remainingMs <= 0) {
          // Invece di navigare, chiamiamo la callback
          if (!_timerExpiredProcessed) {
            _timerExpiredProcessed = true; 
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                widget.onTimerEnd?.call();
              }
            });
          }
          return _buildBarWithText(0.0, Colors.red, "00:00", Colors.white);
        }

        final double totalDurationMs = durationSec * 1000.0;
        final double progress = (remainingMs / totalDurationMs).clamp(0.0, 1.0);
        
        Color barColor = remainingSeconds <= 30 ? Colors.red : Theme.of(context).colorScheme.primary;

        return _buildBarWithText(progress, barColor, _formatTime(remainingSeconds), Theme.of(context).colorScheme.secondary);
      },
    );
  }

  Widget _buildBarWithText(double progress, Color barColor, String text, Color textColor) {
    return Row(
      children: [
        Icon(Icons.hourglass_bottom, size: 36, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 32,
                  color: Colors.grey[350], 
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress, 
                    child: Container(
                      height: 32,
                      color: barColor,
                    ),
                  ),
                ),
                Text(
                  text,
                  style: TextStyle(
                    color: textColor == Colors.white ? Colors.black : textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    shadows: textColor == Colors.white ? [const Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.white)] : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}