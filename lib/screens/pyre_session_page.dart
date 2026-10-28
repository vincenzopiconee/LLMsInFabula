import 'dart:async';
import 'dart:math'; // Importante per la scelta random
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import '../functions/pyre_timer.dart';
import 'voting_result_day.dart';

class PyreSessionPage extends StatefulWidget {
  final String roomId;
  final String uid;

  const PyreSessionPage({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<PyreSessionPage> createState() => _PyreSessionPageState();
}

class _PyreSessionPageState extends State<PyreSessionPage> {
  late DatabaseReference _roomRef;
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  
  // Cache locale dei dati
  Map<String, dynamic>? _roomData;
  
  String? selectedPlayerUid;
  bool _hasVoted = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");
    
    // Aggiorniamo stato fase
    _roomRef.child("players/${widget.uid}/phaseStatus").set("pyre_session");

    // --- INIZIALIZZAZIONE TIMER (Solo Host) ---
    _initializeTimerIfHost();

    // Sottoscrizione al database
    _roomSubscription = _roomRef.onValue.listen((event) {
      if (event.snapshot.value == null) {
        if (mounted) {
          _roomSubscription?.cancel();
          onRoomClosed(context);
        }
        return;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      // --- LOGICA DI NAVIGAZIONE E ADMIN ---
      final String currentState = data['state'] ?? '';
      
      // 1. Navigazione
      if (currentState == 'voting_results' && !_hasNavigated && mounted) {
        _hasNavigated = true;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => VotingResultDay(roomId: widget.roomId, uid: widget.uid)));
        return;
      }

      // 2. Logica Admin (Calcolo Risultati)
      final adminId = data['adminId'];
      final bool isHost = (adminId == widget.uid);
      
      if (isHost && currentState != 'voting_results') {
        _checkAndTriggerRunoff(data);
      }

      // 3. Aggiornamento UI Locale
      if (mounted) {
        setState(() {
          _roomData = data;
        });
      }
    });
  }

  Future<void> _initializeTimerIfHost() async {
    final snapshot = await _roomRef.child("adminId").get();
    if (snapshot.exists && snapshot.value == widget.uid) {
      // Sono l'Host: avvio il timer di 60 secondi
      await _roomRef.update({
        'timer': {
          'startTime': ServerValue.timestamp,
          'duration': 60 // Fisso a 1 minuto come richiesto
        }
      });
    }
  }

  // --- LOGICA TIMER SCADUTO ---
  void _handleTimerEnd() {
    if (_hasVoted) return; // Se ho già votato, ignoro


    if (selectedPlayerUid != null) {
      // Caso 1: Ho selezionato qualcuno ma non confermato -> Confermo ora
      _submitPyreVote(selectedPlayerUid!);
    } else {
      // Caso 2: Non ho selezionato nessuno -> Scelta Randomica
      if (_roomData != null) {
        final playersMap = Map<String, dynamic>.from(_roomData!['players'] ?? {});
        final tiedPlayersIds = List<Object?>.from(_roomData!['tied_players'] ?? []);
        
        // Costruisco la lista dei candidati validi
        final List<String> validCandidates = [];
        for (var id in tiedPlayersIds) {
          if (id is String && playersMap.containsKey(id)) {
            validCandidates.add(id);
          }
        }

        if (validCandidates.isNotEmpty) {
          final randomUid = validCandidates[Random().nextInt(validCandidates.length)];
          _submitPyreVote(randomUid);
        } else {
          // Caso estremo (nessun candidato valido?): voto nullo o skip
          // In teoria non dovrebbe accadere se siamo qui
        }
      }
    }
  }

  /// Estrazione della logica Admin per pulizia
  void _checkAndTriggerRunoff(Map<String, dynamic> data) {
    final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
    final votesMap = Map<String, dynamic>.from(data['pyre_votes'] ?? {});

    int totalAliveCount = 0;
    playersMap.forEach((key, value) {
      if (value is Map && value['alive'] == true && value['role'] != 'Spectator') {
        totalAliveCount++;
      }
    });

    int currentVotesCount = 0;
    votesMap.forEach((voterUid, val) {
      if (playersMap.containsKey(voterUid)) {
        final voterData = playersMap[voterUid];
        if (voterData is Map && voterData['alive'] == true) {
          currentVotesCount++;
        }
      }
    });

    if (totalAliveCount > 0 && currentVotesCount >= totalAliveCount) {
      Future.microtask(() => _calculateRunoff(votesMap));
    }
  }

  Future<void> _submitPyreVote(String voteValue) async {
    setState(() {
      _hasVoted = true;
      selectedPlayerUid = voteValue; // Aggiorno la UI per mostrare chi è stato scelto (anche se random)
    });
    await _roomRef.child("pyre_votes/${widget.uid}").set(voteValue);
  }

  Future<void> _calculateRunoff(Map<dynamic, dynamic> votes) async {
    Map<String, int> voteCounts = {};
    votes.forEach((voter, target) {
      voteCounts[target] = (voteCounts[target] ?? 0) + 1;
    });

    String result = "nobody";
    int maxVotes = 0;
    
    voteCounts.forEach((target, count) {
      if (count > maxVotes) {
        maxVotes = count;
        result = target;
      } else if (count == maxVotes) {
        result = "nobody"; // Ancora pareggio -> Nessuno muore
      }
    });

    if (result != "nobody") {
      await _roomRef.child("players/$result/alive").set(false);
    }

    await _roomRef.update({
      "day_result": result,
      "state": "voting_results"
    });
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        key: scaffoldKey,
        drawer: const RoleRulesDrawer(),
        backgroundColor: colorScheme.secondary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.menu_book, color: colorScheme.onSecondary),
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
            ),
          ), 
          actions: [
            IconButton(
              icon: Icon(Icons.close, color: colorScheme.onSecondary, size: 28),
              onPressed: () => handleExit(context: context, roomRef: _roomRef, uid: widget.uid),
            ),
          ],
        ),
        body: _roomData == null
            ? const Center(child: CircularProgressIndicator())
            : Builder(
                builder: (context) {
                  final data = _roomData!;
                  final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
                  final tiedPlayersIds = List<Object?>.from(data['tied_players'] ?? []); 
                  final votesMap = Map<String, dynamic>.from(data['pyre_votes'] ?? {});

                  // Filtriamo SOLO i giocatori al ballottaggio
                  final List<Map<String, dynamic>> runoffCandidates = [];
                  for (var id in tiedPlayersIds) {
                    if (id is String && playersMap.containsKey(id)) {
                      runoffCandidates.add({'uid': id, 'name': playersMap[id]['name']});
                    }
                  }

                  // Calcolo per la UI (conteggio voti)
                  int totalAliveCount = 0;
                  playersMap.forEach((key, value) {
                    if (value is Map && value['alive'] == true && value['role'] != 'Spectator') {
                      totalAliveCount++;
                    }
                  });

                  int currentVotesCount = 0;
                  votesMap.forEach((voterUid, val) {
                    if (playersMap.containsKey(voterUid)) {
                      final voterData = playersMap[voterUid];
                      if (voterData is Map && voterData['alive'] == true) {
                        currentVotesCount++;
                      }
                    }
                  });

                  return SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              
                              // --- NUOVO TIMER DINAMICO ---
                              PyreTimerWidget(
                                roomId: widget.roomId, 
                                uid: widget.uid, 
                                onTimerEnd: _handleTimerEnd, // Collega la logica di fine tempo
                              ),

                              const SizedBox(height: 40),

                              Stack(
                                children: [
                                  Positioned(top: 6, child: Text('PYRE\n Session', style: TextStyle(fontSize: 57, fontWeight: FontWeight.w900, foreground: Paint()..color = const Color.fromARGB(255, 205, 7, 7), letterSpacing: 1), textAlign: TextAlign.center)),
                                  Text('PYRE\n Session', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, foreground: Paint()..color = const Color.fromARGB(255, 239, 151, 8), letterSpacing: 2), textAlign: TextAlign.center),
                                ],
                              ),
                        
                              const SizedBox(height: 30),
                              Text('Who do you want to\nkick out of the village?', style: textTheme.titleMedium!.copyWith(fontSize: 30, fontWeight: FontWeight.w500, color: colorScheme.onSecondary, height: 1.3), textAlign: TextAlign.center),
                              const SizedBox(height: 40),

                              // LISTA CANDIDATI AL BALLOTTAGGIO
                              if (!_hasVoted)
                                Expanded(
                                  child: Scrollbar(
                                    thumbVisibility: true,
                                    child: ListView.builder(
                                      itemCount: runoffCandidates.length,
                                      itemBuilder: (context, index) {
                                        final player = runoffCandidates[index];
                                        final isSelected = selectedPlayerUid == player['uid'];
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12.0, right: 8),
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isSelected ? Colors.grey[400] : colorScheme.primary,
                                              foregroundColor: isSelected ? colorScheme.secondary : colorScheme.onPrimary,
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                if (selectedPlayerUid == player['uid']) {
                                                  selectedPlayerUid = null;
                                                } else {
                                                  selectedPlayerUid = player['uid'];
                                                }
                                              });
                                            },
                                            child: Text(player['name'], style: textTheme.titleMedium!.copyWith(fontSize: 22, fontWeight: FontWeight.w600, color: isSelected ? colorScheme.primary : colorScheme.onPrimary)),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                )
                              else 
                                const Spacer(),

                              const SizedBox(height: 20),

                              if (!_hasVoted)
                                Center(
                                  child: SizedBox(
                                    width: 200,
                                    height: 58,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: selectedPlayerUid != null ? colorScheme.onSecondary : Colors.grey, 
                                        foregroundColor: colorScheme.secondary,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: selectedPlayerUid != null ? () => _submitPyreVote(selectedPlayerUid!) : null,
                                      child: Text(
                                        'Confirm',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Column(
                                  children: [
                                    const CircularProgressIndicator(color: Colors.white),
                                    const SizedBox(height: 20),
                                    Text("$currentVotesCount / $totalAliveCount voted", style: TextStyle(color: colorScheme.onSecondary, fontStyle: FontStyle.italic, fontSize: 20)),
                                  ],
                                ),

                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
              ),
      )
    );
  }
}