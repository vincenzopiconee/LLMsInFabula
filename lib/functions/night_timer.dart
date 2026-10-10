import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import '../screens/return_to_sleep_screen.dart';
import '../services/role_data.dart'; 
// Assicurati che questo import punti al file corretto nel tuo progetto

class NightTimerWidget extends StatefulWidget {
  final String roomId;
  final String uid;
  final VoidCallback? onTimerEnd;
  final String? fixedRole; // <--- 1. NUOVO PARAMETRO
  final bool returnedToSleep;

  const NightTimerWidget({
    super.key, 
    required this.roomId, 
    required this.uid,
    this.onTimerEnd,
    this.fixedRole, // <--- Aggiunto al costruttore
    this.returnedToSleep = false,
  });

  @override
  State<NightTimerWidget> createState() => _NightTimerWidgetState();
}

class _NightTimerWidgetState extends State<NightTimerWidget> {
  late DatabaseReference _timerRef;
  Timer? _uiTicker;
  bool _hasNavigated = false;
  
  // Colore di default (grey)
  Color _roleColor = Colors.grey; 

  @override
  void initState() {
    super.initState();
    
    _timerRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}/timer");
    
    // 2. LOGICA OTTIMIZZATA:
    // Se ci passano il ruolo, impostiamo il colore SUBITO (sincrono)
    if (widget.fixedRole != null && rolesData.containsKey(widget.fixedRole)) {
      _roleColor = rolesData[widget.fixedRole]!.color;
    } else {
      // Altrimenti proviamo a scaricarlo dal DB (asincrono, fallback)
      _fetchUserRoleColor();
    }

    _uiTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _fetchUserRoleColor() async {
    try {
      final snapshot = await FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: kDatabaseUrl,
      ).ref("rooms/${widget.roomId}/players/${widget.uid}/role").get();

      if (snapshot.exists && snapshot.value != null && mounted) {
        final String role = snapshot.value.toString();
        if (rolesData.containsKey(role)) {
          setState(() {
            _roleColor = rolesData[role]!.color;
          });
        }
      }
    } catch (e) {
      debugPrint("Errore recupero colore ruolo: $e");
    }
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
        final int durationSec = _safeInt(data['duration'], 60);

        if (startTime == 0) return _buildBarWithText(1.0, Colors.grey, "Ready...", Colors.black54);

        final int now = DateTime.now().millisecondsSinceEpoch;
        final int endTime = startTime + (durationSec * 1000);
        final int remainingMs = endTime - now;
        final int remainingSeconds = (remainingMs / 1000).ceil();

        if (remainingMs <= 0) {
          if (!_hasNavigated) {
            _hasNavigated = true; 
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                if (widget.onTimerEnd != null) {
                  widget.onTimerEnd!();
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoBackToSleepScreen(
                        roomId: widget.roomId,
                        uid: widget.uid,
                      ),
                    ),
                  );
                }
              }
            });
          }
          return _buildBarWithText(0.0, Colors.red, "00:00", Colors.white);
        }

        final double totalDurationMs = durationSec * 1000.0;
        final double progress = (remainingMs / totalDurationMs).clamp(0.0, 1.0);
        
        // Rosso se mancano 10 secondi, altrimenti colore del ruolo
        Color barColor = remainingSeconds <= 10 ? Colors.red : _roleColor;

        return _buildBarWithText(progress, barColor, _formatTime(remainingSeconds), Colors.white);
      },
    );
  }

  Widget _buildBarWithText(double progress, Color barColor, String text, Color textColor) {
    return Row(
      children: [
        const Icon(Icons.hourglass_bottom, size: 36, color: Colors.white),
        const SizedBox(width: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 32,
                  color: Colors.grey[300], 
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress, 
                    child: Container(
                      height: 32,
                      color: widget.returnedToSleep ? Colors.grey : barColor,
                    ),
                  ),
                ),
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