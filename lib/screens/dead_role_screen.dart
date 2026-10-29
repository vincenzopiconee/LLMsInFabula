import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';

// Import delle pagine di navigazione
import 'werewolf_victory_screen.dart';
import 'farmer_victory_screen.dart';
import 'daytime_page.dart';        
import 'voting_result_day.dart';   
import 'recap_night_page.dart';

class DeadRoleRevealScreen extends StatefulWidget {
  final String roomId;
  final String uid;

  const DeadRoleRevealScreen({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<DeadRoleRevealScreen> createState() => _DeadRoleRevealScreenState();
}

class _DeadRoleRevealScreenState extends State<DeadRoleRevealScreen> {
  late DatabaseReference _roomRef;
  bool _hasNavigated = false; 
  bool _isCalculating = false;
  
  // Timer locale
  Timer? _deadTimerTicker; 
  bool _updateSent = false;

  // Variabile per memorizzare i dati attuali senza ridisegnare
  Map<String, dynamic>? _latestData;

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");

    _deadTimerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_latestData != null && mounted) {
        _performAdminChecks(_latestData!);
      }
    });
  }

  @override
  void dispose() {
    _deadTimerTicker?.cancel();
    super.dispose();
  }

  void _performAdminChecks(Map<String, dynamic> data) {
    final String adminId = data['adminId'] ?? '';
    final bool isHost = (adminId == widget.uid);
    final String currentState = data['state'] ?? '';

    if (isHost) {
      if (currentState == 'discussion') {
        _checkDiscussionTimerAndProceed(data);
      }
    }
  }

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
      await _roomRef.update({
        "tied_players": tiedPlayers,
        "state": "pyre_intro"
      });
    } else {
      String result = (tiedPlayers.isNotEmpty) ? tiedPlayers.first : "nobody";
      if (result != "nobody") {
        await _roomRef.child("players/$result/alive").set(false);
      }
      await _roomRef.update({
        "day_result": result,
        "state": "voting_results"
      });
    }
    _isCalculating = false;
  }

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

    await _roomRef.update({
      "day_result": result,
      "state": "voting_results"
    });
    _isCalculating = false;
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

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Recupero width per eventuali calcoli
    //final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      child: Scaffold(
        key: scaffoldKey,
        drawer: const RoleRulesDrawer(),
        backgroundColor: colorScheme.secondary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          leadingWidth: 150,
          leading: RoleGuideDrawerButton(
            color: colorScheme.onSecondary,
            scaffoldKey: scaffoldKey,
          ), 
          actions: [
            IconButton(
              icon: Icon(Icons.close, color: colorScheme.onSecondary, size: 28),
              onPressed: () => handleExit(context: context, roomRef: _roomRef, uid: widget.uid),
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

            final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
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

            // --- LOGICHE ADMIN (OMESSE PER BREVITÀ, SONO IDENTICHE A PRIMA) ---
            if (isHost) {
              int totalAliveCount = 0;
              playersMap.forEach((key, value) {
                if (value is Map && value['alive'] == true && value['role'] != 'Spectator') totalAliveCount++;
              });
              if (totalAliveCount > 0) {
                  if (currentState != 'voting_results' && currentState != 'pyre_intro' && currentState != 'pyre_session' && currentState != 'discussion') {
                    int currentVotesCount = 0;
                    playersMap.forEach((key, value) {
                        if (value is Map && value['alive'] == true && value['role'] != 'Spectator' && votesMap.containsKey(key)) currentVotesCount++;
                    });
                    if (currentVotesCount >= totalAliveCount) Future.microtask(() => _calculateAndCloseVoting(votesMap));
                  } else if (currentState == 'pyre_intro') {
                    int readyCount = 0;
                    playersMap.forEach((key, value) {
                        if (value is Map && value['alive'] == true && value['role'] != 'Spectator' && value['isReadyForPyre'] == true) readyCount++;
                    });
                    if (readyCount >= totalAliveCount) {
                        Future.microtask(() async {
                          await _roomRef.update({
                            'state': 'pyre_session',
                            'timer': {'startTime': ServerValue.timestamp, 'duration': 60}
                          });
                        });
                    }
                  } else if (currentState == 'pyre_session') {
                    int currentPyreVotes = 0;
                    playersMap.forEach((key, value) {
                        if (value is Map && value['alive'] == true && value['role'] != 'Spectator' && pyreVotesMap.containsKey(key)) currentPyreVotes++;
                    });
                    if (currentPyreVotes >= totalAliveCount) Future.microtask(() => _calculateRunoff(pyreVotesMap));
                  }
              }
            }

            // --- NAVIGAZIONE ---
            if (!_hasNavigated) {
              if (currentState == 'victory_werewolves') {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WerewolvesWinScreen(roomId: widget.roomId, uid: widget.uid))));
              } else if (currentState == 'victory_farmers') {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FarmersWinScreen(roomId: widget.roomId, uid: widget.uid))));
              } else if (currentState == 'day_phase') {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DayTimeScreen(roomId: widget.roomId, uid: widget.uid))));
              } else if (currentState == 'recap_night') {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RecapNightPage(roomId: widget.roomId, uid: widget.uid))));
              } else if (currentState == 'voting_results') {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VotingResultDay(roomId: widget.roomId, uid: widget.uid))));
              } 
            }

            // --- UI FIXATA ---
            return SafeArea(
              child: SizedBox(
                width: double.infinity, // Centra tutto orizzontalmente
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      //const Spacer(flex: 1),

                      Text(
                        'You are...',
                        style: textTheme.titleLarge!.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      Flexible(
                        flex: 10,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 5,
                                child: Text(
                                  'DEAD',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 57, 
                                    fontWeight: FontWeight.w900, 
                                    foreground: Paint()..color = Colors.grey,
                                    letterSpacing: 1
                                  ),
                                ),
                              ),
                              Text(
                                'DEAD',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 56, 
                                  fontWeight: FontWeight.w900, 
                                  foreground: Paint()..color = colorScheme.onSecondary,
                                  letterSpacing: 2
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Sostituito SizedBox fisso con Spacer
                      const Spacer(flex: 1),

                      Flexible(
                        flex: 20, 
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.secondary,
                              border: Border.all(
                                color: Colors.grey, 
                                width: 8,
                              ),
                            ),
                            child: const Center(
                              child: Image(
                                image: AssetImage('assets/images/dead.png'), 
                                width: 220, 
                                height: 220
                              )
                            )
                          ),
                        ),
                      ),
                      
                      // Sostituito SizedBox fisso con Spacer
                      const Spacer(flex: 2),

                      // Contenitore testo flessibile con scroll interno per sicurezza
                      Flexible(
                        flex: 20,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24), 
                          decoration: BoxDecoration(
                            color: colorScheme.primary, 
                            border: Border.all(color: colorScheme.primary, width: 2), 
                            borderRadius: BorderRadius.circular(20)
                          ), 
                          child: Text(
                            "Your voice is lost to the wind. You are now a spirit of the village, watching the battle between light and darkness from beyond the grave.", 
                            style: textTheme.bodyLarge!.copyWith(
                              fontSize: 18, 
                              fontWeight: FontWeight.w500, 
                              color: colorScheme.onPrimary, 
                              height: 1.4
                            ), 
                            textAlign: TextAlign.center
                          ),
                        ),
                      ),
                      
                      const Spacer(flex: 3),
                    ],
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