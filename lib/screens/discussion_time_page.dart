import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import '../functions/discussion_timer.dart';
import 'voting_time_page.dart'; 

class DiscussionTimePage extends StatefulWidget {
  final String roomId;
  final String uid;

  const DiscussionTimePage({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<DiscussionTimePage> createState() => _DiscussionTimePageState();
}

class _DiscussionTimePageState extends State<DiscussionTimePage> {
  late DatabaseReference _roomRef;
  bool _hasNavigated = false;
  bool _iAmReady = false; 
  bool _updateSent = false;

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");
    
    _roomRef.child("players/${widget.uid}").update({
      "phaseStatus": "discussion",
      "isReadyForVoting": false, 
    });
  }

  Future<void> _setReadyForVoting() async {
    setState(() {
      _iAmReady = true;
    });
    await _roomRef.child("players/${widget.uid}/isReadyForVoting").set(true);
  }

  // Funzione centralizzata per passare alla fase di voto (chiamata da bottone Ready o Timer Scaduto)
  void _triggerVotingPhase(String votingTimeStr) {
    if (!_updateSent) {
      _updateSent = true;
      Future.microtask(() async {
          int durationSeconds = parseDuration(votingTimeStr);
          await _roomRef.update({
            'state': 'voting',
            'timer': {
              'startTime': ServerValue.timestamp, // Resetta il timer per la nuova fase
              'duration': durationSeconds
            }
          });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child:
        Scaffold(
          backgroundColor: colorScheme.secondary,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(Icons.close, color: colorScheme.onSecondary, size: 28),
                onPressed: () {
                  handleExit(context: context, roomRef: _roomRef, uid: widget.uid);
                },
              ),
            ],
          ),
          
          body: StreamBuilder(
            stream: _roomRef.onValue,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.snapshot.value == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    onRoomClosed(context);
                  }
                });
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.snapshot.value as Map;
              final playersRaw = data['players'];
              final Map<dynamic, dynamic> playersMap = (playersRaw is Map) ? playersRaw : {};

              final String currentState = data['state'] ?? '';
              final String adminId = data['adminId'] ?? '';
              final bool isHost = (widget.uid == adminId);

              final settings = data['settings'] != null ? Map<String, dynamic>.from(data['settings']) : {};
              final timeRules = settings['timeRules'] != null ? Map<String, dynamic>.from(settings['timeRules']) : {};
              final String votingTimeStr = timeRules['voting'] ?? "2m";

              // --- CALCOLO QUORUM (SOLO VIVI) ---
              int totalAlivePlayers = 0;
              int readyPlayers = 0;

              playersMap.forEach((key, value) {
                if (value is Map) {
                  final player = Map<String, dynamic>.from(value);
                  if (player['alive'] == true && player['role'] != 'Spectator') {
                    totalAlivePlayers++;
                    if (player['isReadyForVoting'] == true) {
                      readyPlayers++;
                    }
                  }
                }
              });

              // 1. Navigazione Automatica se TUTTI pronti (Logica "Ready Button")
              if (totalAlivePlayers > 0 && readyPlayers == totalAlivePlayers && currentState != 'voting') {
                 // Qualsiasi giocatore vivo può attivare il trigger se tutti sono pronti
                 _triggerVotingPhase(votingTimeStr);
              }

              // 2. Navigazione reale verso la pagina successiva
              // Scatta quando 'state' diventa 'voting' nel DB (aggiornato da timer o ready)
              if (currentState == 'voting' && !_hasNavigated) {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VotingTimePage(
                        roomId: widget.roomId,
                        uid: widget.uid,
                      ),
                    ),
                  );
                });
              }

              return Column(
                children: [
                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: DiscussionTimerWidget(
                      roomId: widget.roomId, 
                      uid: widget.uid,
                      // --- QUI LA SOLUZIONE AL PROBLEMA ---
                      onTimerEnd: () {
                        // Se il timer scade, l'Host forza il passaggio alla fase successiva
                        // resettando il timer nel DB per la VotingPage.
                        if (isHost) {
                          _triggerVotingPhase(votingTimeStr);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 25),

                  Text(
                    'Discussion Time',
                    style: textTheme.titleLarge!.copyWith(
                      fontSize: 45,
                      color: colorScheme.onSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                
                  const SizedBox(height: 15),
                  
                  Container(
                      width: 280,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.transparent,            // niente rettangolo pieno
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colorScheme.onSecondary,
                          width: 3,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: const Image(
                          image: AssetImage('assets/images/discussion.png'),
                          fit: BoxFit.cover,                  // riempie senza lasciare bordi
                        ),
                      ),
                    ),

                  const SizedBox(height: 25),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60.0),
                    child: Text(
                      'Discuss among yourselves to find the werewolves',
                      style: textTheme.titleLarge!.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const Spacer(flex: 2),

                  Column(
                    children: [
                      SizedBox(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _iAmReady ? colorScheme.secondary : colorScheme.primary, 
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 40),
                            elevation: 0,
                          ),
                          onPressed: _iAmReady ? null : _setReadyForVoting,
                          child: Text(
                            _iAmReady ? 'Waiting others...' : 'Go to Voting',
                            style: textTheme.titleMedium!.copyWith(
                              fontSize: 24,
                              color: _iAmReady ? colorScheme.primary : colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      Text(
                        "$readyPlayers / $totalAlivePlayers ready",
                        style: TextStyle(
                          color: colorScheme.onSecondary, 
                          fontStyle: FontStyle.italic,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              );
            }
          ),
        ),
    );
  }
}