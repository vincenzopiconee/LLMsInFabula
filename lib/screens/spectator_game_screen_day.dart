import 'dart:async'; // Import necessario per il Timer
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import 'voting_result_day.dart'; 

class SpectatorFormScreenDay extends StatefulWidget {
  final String roomId;
  final String uid;
  
  const SpectatorFormScreenDay({
    super.key, 
    required this.roomId, 
    required this.uid
    });

  @override
  State<SpectatorFormScreenDay> createState() => _SpectatorFormScreenState();
}

class _SpectatorFormScreenState extends State<SpectatorFormScreenDay> {
  late DatabaseReference _roomRef;
  bool _hasNavigated = false;
  bool _isCalculating = false; 

  // Variabili per la gestione Host/Timer
  Timer? _adminTimerTicker;
  Map<String, dynamic>? _latestData;
  bool _updateSent = false;

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");

    // --- TIMER SILENZIOSO PER L'HOST ---
    _adminTimerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_latestData != null && mounted) {
        _performAdminChecks(_latestData!);
      }
    });
  }

  @override
  void dispose() {
    _adminTimerTicker?.cancel();
    super.dispose();
  }

  // --- LOGICA GESTIONE TIMER HOST ---
  void _performAdminChecks(Map<String, dynamic> data) {
    final String adminId = data['adminId'] ?? '';
    final bool isHost = (adminId == widget.uid);
    final String currentState = data['state'] ?? '';

    if (isHost) {
      // Controllo scadenza Discussion Timer
      if (currentState == 'discussion') {
        _checkDiscussionTimerAndProceed(data);
      }
    }
  }

  void _checkDiscussionTimerAndProceed(Map data) {
    if (_updateSent) return; 

    final timerData = data['timer'] as Map? ?? {};
    final int startTime = timerData['startTime'] ?? 0;
    final int duration = timerData['duration'] ?? 0; 

    if (startTime == 0) return;

    final int now = DateTime.now().millisecondsSinceEpoch;
    final int endTime = startTime + (duration * 1000);
    
    if (now >= endTime) {
      _updateSent = true;

      final settings = data['settings'] != null ? Map<String, dynamic>.from(data['settings']) : {};
      final timeRules = settings['timeRules'] != null ? Map<String, dynamic>.from(settings['timeRules']) : {};
      final String votingTimeStr = timeRules['voting'] ?? "2m";
      final int votingDurationSeconds = parseDuration(votingTimeStr);

      Future.microtask(() async {
        await _roomRef.update({
          'state': 'voting',
          'timer': {
            'startTime': ServerValue.timestamp,
            'duration': votingDurationSeconds
          }
        });
        
        await Future.delayed(const Duration(seconds: 5));
        if (mounted) _updateSent = false; 
      });
    }
  }

  // --- LOGICA ADMIN 1 (Calcolo Voti) ---
  Future<void> _calculateAndCloseVoting(Map<dynamic, dynamic> votes) async {
    if (_isCalculating) return;
    _isCalculating = true;

    Map<String, int> voteCounts = {};
    votes.forEach((voter, target) {
      if (target != "skip") {
        voteCounts[target] = (voteCounts[target] ?? 0) + 1;
      }
    });

    int maxVotes = 0;
    voteCounts.forEach((target, count) {
      if (count > maxVotes) maxVotes = count;
    });

    List<String> tiedPlayers = [];
    voteCounts.forEach((target, count) {
      if (count == maxVotes) tiedPlayers.add(target);
    });

    if (tiedPlayers.length > 1) {
      await _roomRef.update({"tied_players": tiedPlayers, "state": "pyre_intro"});
    } else {
      String result = (tiedPlayers.isNotEmpty) ? tiedPlayers.first : "nobody";
      if (result != "nobody") {
        await _roomRef.child("players/$result/alive").set(false);
      }
      await _roomRef.update({"day_result": result, "state": "voting_results"});
    }
    _isCalculating = false;
  }

  // --- LOGICA ADMIN 2 (SPAREGGIO) ---
  Future<void> _calculateRunoff(Map<dynamic, dynamic> votes) async {
    if (_isCalculating) return;
    _isCalculating = true;

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
        result = "nobody"; 
      }
    });

    if (result != "nobody") {
      await _roomRef.child("players/$result/alive").set(false);
    }
    await _roomRef.update({"day_result": result, "state": "voting_results"});
    _isCalculating = false;
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
    final colorScheme = Theme.of(context).colorScheme;
    
    final allRolesOrder = ['Werewolf', 'Medium', 'Seer', 'Doctor', 'Farmer', 'Dead'];
    
    final roleColors = {
      'Werewolf': const Color(0xFF8B0000), 'Medium': const Color(0xFF9A5EA8), 'Seer': const Color(0xFF166AF1),
      'Doctor': const Color(0xFF5A8920), 'Farmer': const Color.fromARGB(255, 141, 134, 29), 'Dead': Colors.grey,
    };

    return PopScope(
      canPop: false,
      child: Scaffold(
        key: scaffoldKey,
        drawer: const RoleRulesDrawer(),
        backgroundColor: colorScheme.secondary, 
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Builder(builder: (ctx) => IconButton(icon: Icon(Icons.menu_book, color: colorScheme.onSecondary), onPressed: () => scaffoldKey.currentState?.openDrawer())), 
          actions: [IconButton(icon: Icon(Icons.close, color: colorScheme.onSecondary), onPressed: () => handleExit(context: context, roomRef: _roomRef, uid: widget.uid))],
        ),
        body: StreamBuilder(
          stream: _roomRef.onValue,
          builder: (context, snapshot) {
            
            if (snapshot.hasData && snapshot.data!.snapshot.value == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La lobby è stata chiusa dall'host."), backgroundColor: Colors.red));
                }
              });
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
            
            // Aggiorna i dati per il timer silenzioso
            _latestData = data;

            final String currentState = data['state'] ?? '';
            final adminId = data['adminId'];
            final bool isHost = (adminId == widget.uid);

            final playersRaw = data['players'];
            final Map<dynamic, dynamic> playersMap = (playersRaw is Map) ? playersRaw : {};
            final votesRaw = data['day_votes'];
            final Map<dynamic, dynamic> votesMap = (votesRaw is Map) ? votesRaw : {};
            final pyreVotesRaw = data['pyre_votes'];
            final Map<dynamic, dynamic> pyreVotesMap = (pyreVotesRaw is Map) ? pyreVotesRaw : {};

            // --- LOGICA ADMIN (SPECTATOR) ---
            if (isHost) {
              int totalAliveCount = 0;
              playersMap.forEach((key, value) {
                if (value is Map && value['alive'] == true && value['role'] != 'Spectator') totalAliveCount++;
              });

              if (totalAliveCount > 0) {
                // A. Voto Normale
                if (currentState != 'voting_results' && currentState != 'pyre_intro' && currentState != 'pyre_session' && currentState != 'discussion') {
                    int currentVotesCount = 0;
                    playersMap.forEach((key, value) {
                      if (value is Map && value['alive'] == true && value['role'] != 'Spectator' && votesMap.containsKey(key)) currentVotesCount++;
                    });
                    if (currentVotesCount >= totalAliveCount) Future.microtask(() => _calculateAndCloseVoting(votesMap));
                }
                // B. Pyre Intro (AGGIORNATO: RESET TIMER)
                else if (currentState == 'pyre_intro') {
                    int readyCount = 0;
                    playersMap.forEach((key, value) {
                        if (value is Map && value['alive'] == true && value['role'] != 'Spectator' && value['isReadyForPyre'] == true) readyCount++;
                    });
                    
                    if (readyCount >= totalAliveCount) {
                      Future.microtask(() async {
                        // Resettiamo timer e stato insieme per avviare correttamente la Pyre Session
                        await _roomRef.update({
                          'state': 'pyre_session',
                          'timer': {
                            'startTime': ServerValue.timestamp,
                            'duration': 60 // 1 Minuto per la Pyre
                          }
                        });
                      });
                    }
                }
                // C. Pyre Session
                else if (currentState == 'pyre_session') {
                    int currentPyreVotes = 0;
                    playersMap.forEach((key, value) {
                        if (value is Map && value['alive'] == true && value['role'] != 'Spectator' && pyreVotesMap.containsKey(key)) currentPyreVotes++;
                    });
                    if (currentPyreVotes >= totalAliveCount) Future.microtask(() => _calculateRunoff(pyreVotesMap));
                }
              }
            }

            // --- NAVIGAZIONE ---
            if (currentState == 'voting_results' && !_hasNavigated) {
              _hasNavigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VotingResultDay(roomId: widget.roomId, uid: widget.uid)));
              });
            }

            // --- FILTRO RUOLI ---
            final Map<String, List<String>> rolePlayers = {
              'Werewolf': [], 'Medium': [], 'Seer': [], 'Doctor': [], 'Farmer': [], 'Dead': []
            };

            playersMap.forEach((key, value) {
              if (value is Map) {
                final player = Map<String, dynamic>.from(value);
                final String name = player['name'] ?? 'Player';
                final String role = player['role'] ?? 'Farmer';
                final bool isAlive = player['alive'] == true;
                
                String displayName = name;
                if (!isAlive) displayName += " (💀)";

                if (rolePlayers.containsKey(role)) rolePlayers[role]!.add(displayName);
                if (!isAlive) rolePlayers['Dead']!.add("$name ($role)");
              }
            });

            final List<String> activeRoles = allRolesOrder.where((role) {
              return rolePlayers[role] != null && rolePlayers[role]!.isNotEmpty;
            }).toList();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(width: 64, height: 64, decoration: BoxDecoration(color: colorScheme.onSecondary, shape: BoxShape.circle), child: Icon(Icons.remove_red_eye, size: 40, color: colorScheme.secondary)),
                        const SizedBox(width: 24),
                        Expanded(child: Text('SPECTATOR', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: colorScheme.onSecondary, letterSpacing: 1.3, shadows: [Shadow(offset: Offset(2, 4), color: Colors.black26, blurRadius: 4)]))),
                      ],
                    ),
                    /*
                    if (isHost && currentState == 'discussion')
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text("Host: Monitoring Timer...", style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic)),
                      ),
                    */
                    const SizedBox(height: 40),
                    
                    Expanded(
                      child: ListView(
                        children: activeRoles.asMap().entries.map((entry) {
                          int idx = entry.key;
                          String role = entry.value;
                          Color color = roleColors[role]!;

                          return Column(
                            children: [
                              Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  key: PageStorageKey(role),
                                  title: RoleTitleStack(text: role, color: color, fontSize: 35),
                                  iconColor: color,
                                  collapsedIconColor: color,
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: EdgeInsets.zero,
                                  children: [
                                      Column(children: rolePlayers[role]!.map((p) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Center(child: Text(p, style: TextStyle(fontSize: 22, color: colorScheme.onSecondary))))).toList()),
                                  ],
                                ),
                              ),
                              if (idx < activeRoles.length - 1) Divider(color: colorScheme.primary, thickness: 2),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
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

// Widget Helper (Invariato)
class RoleTitleStack extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;

  const RoleTitleStack({required this.text, required this.color, required this.fontSize, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned(top: 2, child: Text(text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: color, letterSpacing: 2, fontFamily: Theme.of(context).textTheme.titleLarge?.fontFamily))),
        Text(text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: colorScheme.primary, letterSpacing: 2, fontFamily: Theme.of(context).textTheme.titleLarge?.fontFamily)),
      ],
    );
  }
}