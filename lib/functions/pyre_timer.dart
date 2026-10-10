import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';

class PyreTimerWidget extends StatefulWidget {
  final String roomId;
  final String uid;
  final VoidCallback onTimerEnd;

  const PyreTimerWidget({
    super.key,
    required this.roomId,
    required this.uid,
    required this.onTimerEnd,
  });

  @override
  State<PyreTimerWidget> createState() => _PyreTimerWidgetState();
}

class _PyreTimerWidgetState extends State<PyreTimerWidget> {
  late DatabaseReference _timerRef;
  Timer? _uiTicker;
  bool _actionTriggered = false;

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

  // Helper per formattare i secondi in MM:SS
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
        final int durationSec = _safeInt(data['duration'], 60);

        if (startTime == 0) return _buildBarWithText(1.0, Colors.grey, "Ready...", Colors.black54);

        final int now = DateTime.now().millisecondsSinceEpoch;
        final int endTime = startTime + (durationSec * 1000);
        final int remainingMs = endTime - now;
        final int remainingSeconds = (remainingMs / 1000).ceil();

        // --- SCADENZA TEMPO ---
        if (remainingMs <= 0) {
          if (!_actionTriggered) {
            _actionTriggered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onTimerEnd();
            });
          }
          return _buildBarWithText(0.0, Colors.red, "00:00", Colors.white);
        }

        final double totalDurationMs = durationSec * 1000.0;
        final double progress = (remainingMs / totalDurationMs).clamp(0.0, 1.0);
        
        // Rosso negli ultimi 10 secondi
        Color barColor = remainingSeconds <= 10 ? Colors.red : Theme.of(context).colorScheme.primary;

        // Passiamo _formatTime(remainingSeconds) per vedere i numeri
        return _buildBarWithText(
          progress, 
          barColor, 
          _formatTime(remainingSeconds), 
          Theme.of(context).colorScheme.onPrimary
        );
      },
    );
  }

  Widget _buildBarWithText(double progress, Color barColor, String text, Color textColor) {
    return Row(
      children: [
        Icon(Icons.hourglass_bottom, size: 36, color: Theme.of(context).colorScheme.onSecondary),
        const SizedBox(width: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Sfondo
                Container(
                  height: 32,
                  color: Colors.grey[400], 
                ),
                // Barra di progresso
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
                // Testo (Numeri)
                Text(
                  text,
                  style: TextStyle(
                    color: textColor == Colors.white ? Colors.black : textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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