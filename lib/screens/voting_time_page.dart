import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import '../functions/voting_timer.dart';
import 'voting_result_day.dart'; 
import 'pyre_page.dart'; 
import 'classic/classic_voting_result_page.dart'; 

class VotingTimePage extends StatefulWidget {
  final String roomId;
  final String uid;

  const VotingTimePage({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<VotingTimePage> createState() => _VotingTimePageState();
}

class _VotingTimePageState extends State<VotingTimePage> {
  late DatabaseReference _roomRef;
  String? selectedPlayerUid;
  bool _hasVoted = false;
  bool _hasNavigated = false;

  // --- LOGICA MODIFICATA ---
  void _handleTimerEnd() {
    // Se ho già votato, non faccio nulla
    if (_hasVoted) return;

    if (selectedPlayerUid != null) {
      // Caso 1: Ho selezionato qualcuno ma non ho premuto confirm -> Confermo la scelta
      _submitVote(selectedPlayerUid!);
    } else {
      // Caso 2: Non ho selezionato nessuno -> Voto Skip
      _submitVote("skip");
    }
  }
  // -------------------------
  
  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");
    
    _roomRef.child("players/${widget.uid}/phaseStatus").set("voting");
  }

  Future<void> _submitVote(String voteValue) async {
    setState(() {
      _hasVoted = true;
    });
    await _roomRef.child("day_votes/${widget.uid}").set(voteValue);
  }

  /// Logica Admin Modificata per il Pareggio
  Future<void> _calculateAndCloseVoting(Map<dynamic, dynamic> votes) async {
    Map<String, int> voteCounts = {};
    
    // Conteggio
    votes.forEach((voter, target) {
      if (target != "skip") {
        voteCounts[target] = (voteCounts[target] ?? 0) + 1;
      }
    });

    int maxVotes = 0;
    // Trova il numero massimo di voti
    voteCounts.forEach((target, count) {
      if (count > maxVotes) maxVotes = count;
    });

    // Trova TUTTI i giocatori che hanno quel numero di voti
    List<String> tiedPlayers = [];
    voteCounts.forEach((target, count) {
      if (count == maxVotes) {
        tiedPlayers.add(target);
      }
    });

    // --- LOGICA SPAREGGIO ---
    if (tiedPlayers.length > 1) {
      // PAREGGIO: Salviamo i candidati e andiamo alla Pyre Page
      await _roomRef.update({
        "tied_players": tiedPlayers, // Salviamo chi è al ballottaggio
        "state": "pyre_intro"
      });
    } else {
      // VINCITORE UNICO (o 0 voti totali se tiedPlayers è vuoto)
      String result = (tiedPlayers.isNotEmpty) ? tiedPlayers.first : "nobody";
    
      if (result != "nobody") {
        await _roomRef.child("players/$result/alive").set(false);
      }
    
    // Aggiorno il risultato e cambio fase
      await _roomRef.update({
        "day_result": result,
        "state": "voting_results",
        "generated_stories/current_story": null // questo pulisce la storia per il prossimo step
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.secondary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
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
            final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
            final votesMap = Map<String, dynamic>.from(data['day_votes'] ?? {});
            final adminId = data['adminId'];
            final String currentState = data['state'] ?? '';
            final bool isHost = (adminId == widget.uid);

            final List<Map<String, dynamic>> alivePlayersList = [];
            int totalAliveCount = 0;

            playersMap.forEach((key, value) {
              if (value is Map) {
                final player = Map<String, dynamic>.from(value);
                if (player['alive'] == true && player['role'] != 'Spectator' && player['role'] != 'Narrator') {
                  totalAliveCount++;
                  alivePlayersList.add({'uid': key, 'name': player['name']});
                }
              }
            });

            int currentVotesCount = 0;
            votesMap.forEach((voterUid, val) {
              if (playersMap.containsKey(voterUid)) {
                final voterData = playersMap[voterUid];
                if (voterData is Map && voterData['alive'] == true && voterData['role'] != 'Narrator') {
                  currentVotesCount++;
                }
              }
            });

            final settings = Map<String, dynamic>.from(data['settings'] ?? {});
            final bool isClassic = settings['gameMode'] == 'classic';

            // --- NAVIGAZIONE ---
            if (!_hasNavigated) {
              if (currentState == 'voting_results') {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (isClassic) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClassicVotingResultPage(roomId: widget.roomId, uid: widget.uid),
                      ),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VotingResultDay(roomId: widget.roomId, uid: widget.uid),
                      ),
                    );
                  }
                });
              } else if (currentState == 'pyre_intro') {
                // NUOVA NAVIGAZIONE: Pareggio
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PyreScreen(roomId: widget.roomId, uid: widget.uid)));
                });
              }
            }

            // --- LOGICA ADMIN ---
            if (isHost && totalAliveCount > 0 && currentVotesCount >= totalAliveCount && currentState != 'voting_results' && currentState != 'pyre_intro') {
              if (!_hasNavigated) {
                  Future.microtask(() => _calculateAndCloseVoting(votesMap));
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // ... UI Barra Progresso e Titolo (uguale a prima) ...
                    VotingTimerWidget(
                      roomId: widget.roomId,
                      uid: widget.uid,
                      onTimerEnd: _handleTimerEnd, // Passa la funzione
                    ),
                    const SizedBox(height: 40),
                    Stack(
                      children: [
                        Positioned(top: 6, child: Text('VOTING TIME', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, foreground: Paint()..color = Colors.grey, letterSpacing: 1), textAlign: TextAlign.center)),
                        Text('VOTING TIME', style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: colorScheme.primary, letterSpacing: 2), textAlign: TextAlign.center),
                      ],
                    ),            
                    const SizedBox(height: 30),
                    
                    if (!_hasVoted)
                      Text('Who do you want to\nkick out of the village?', style: textTheme.titleMedium!.copyWith(fontSize: 30, fontWeight: FontWeight.w500, color: colorScheme.onSecondary, height: 1.3), textAlign: TextAlign.center)
                    else
                      Text('Vote Casted.\nWaiting for results...', style: textTheme.titleMedium!.copyWith(fontSize: 30, fontWeight: FontWeight.w500, color: colorScheme.onSecondary, height: 1.3), textAlign: TextAlign.center),
                    
                    const SizedBox(height: 40),

                    if (!_hasVoted)
                      Expanded(
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.builder(
                            itemCount: alivePlayersList.length,
                            itemBuilder: (context, index) {
                              final player = alivePlayersList[index];
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
                              backgroundColor: selectedPlayerUid == null ? colorScheme.primary : colorScheme.onSecondary, 
                              foregroundColor: selectedPlayerUid == null ? colorScheme.onPrimary : colorScheme.secondary,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              if (selectedPlayerUid == null) {
                                _submitVote("skip");
                              } else {
                                _submitVote(selectedPlayerUid!);
                              }
                            },
                            child: Text(
                              selectedPlayerUid == null ? 'Skip' : 'Confirm',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: selectedPlayerUid == null ? colorScheme.onPrimary : colorScheme.secondary,
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
            );
          },
        ),
      )
    );
  }
}