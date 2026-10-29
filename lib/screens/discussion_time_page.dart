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
                  if (player['alive'] == true && player['role'] != 'Spectator' && player['role'] != 'Narrator') {
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

              final screenWidth = MediaQuery.of(context).size.width;
              final horizontalPadding = screenWidth > 900 ? 64.0 : (screenWidth > 600 ? 40.0 : 24.0);

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      int imageFlex;
                      if (constraints.maxWidth >= 1400 && constraints.maxHeight >= 700) {
                        imageFlex = 55;
                      } else if (constraints.maxWidth >= 1000 && constraints.maxHeight >= 620) {
                        imageFlex = 50;
                      } else if (constraints.maxWidth >= 750 && constraints.maxHeight >= 560) {
                        imageFlex = 44;
                      } else if (constraints.maxWidth >= 550 && constraints.maxHeight >= 500) {
                        imageFlex = 38;
                      } else {
                        imageFlex = 30;
                      }

                      return Column(
                        children: [
                          const SizedBox(height: 12),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: DiscussionTimerWidget(
                              roomId: widget.roomId, 
                              uid: widget.uid,
                              onTimerEnd: () {
                                if (isHost) {
                                  _triggerVotingPhase(votingTimeStr);
                                }
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            'Discussion Time',
                            style: textTheme.titleLarge!.copyWith(
                              fontSize: 40,
                              color: colorScheme.onSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        
                          const SizedBox(height: 12),
                          
                          Flexible(
                            flex: imageFlex,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
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
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40.0),
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
                                width: 220,
                                height: 58,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _iAmReady ? colorScheme.secondary : colorScheme.primary, 
                                    foregroundColor: _iAmReady ? colorScheme.primary : colorScheme.onPrimary,
                                    disabledBackgroundColor: colorScheme.secondary,
                                    disabledForegroundColor: colorScheme.primary,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: _iAmReady ? null : _setReadyForVoting,
                                  child: Text(
                                    _iAmReady ? 'Waiting others...' : 'Go to Voting',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: _iAmReady ? colorScheme.primary : colorScheme.onPrimary,
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
                    },
                  ),
                ),
              );
            }
          ),
        ),
    );
  }
}