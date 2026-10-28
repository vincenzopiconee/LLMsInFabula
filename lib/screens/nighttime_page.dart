import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart'; 

// Import delle pagine di azione
import 'werewolf_action_page.dart';
import 'seer_action_page.dart';
import 'doctor_action_page.dart';
import 'medium_action_page.dart';
import 'farmer_action_page.dart';
import 'spectator_game_screen_night.dart';
import 'dead_role_screen.dart'; 

class NightTimeScreen extends StatefulWidget {
  final String roomId;
  final String uid;

  const NightTimeScreen({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<NightTimeScreen> createState() => _NightTimeScreenState();
}

class _NightTimeScreenState extends State<NightTimeScreen> {
  late DatabaseReference _roomRef;
  bool _hasNavigatedToAction = false;

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");

    _roomRef.child("players/${widget.uid}/phaseStatus").set("night");
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
        backgroundColor: colorScheme.primary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.menu_book, color: colorScheme.onPrimary),
              onPressed: () {
                scaffoldKey.currentState?.openDrawer();
              },
            ),
          ), 
          actions: [
            IconButton(
              icon: Icon(Icons.close, color: colorScheme.onPrimary, size: 28),
              onPressed: () {
                handleExit(context: context, roomRef: _roomRef, uid: widget.uid);
              },
            ),
          ],
        ),
        body: StreamBuilder(
          stream: _roomRef.onValue,
          builder: (context, snapshot) {
            
            if (snapshot.hasError) return Center(child: Text("Errore: ${snapshot.error}", style: const TextStyle(color: Colors.white)));

            if (snapshot.hasData && snapshot.data!.snapshot.value == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  onRoomClosed(context);
                }
              });
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final data = snapshot.data!.snapshot.value as Map;
            final adminId = data['adminId'];
            final playersRaw = data['players'];
            final Map<dynamic, dynamic> playersMap = (playersRaw is Map) ? playersRaw : {};
            final String currentState = data['state'] ?? '';

            // 1. Recupera prima la mappa 'settings'
            final settings = data['settings'] != null ? Map<String, dynamic>.from(data['settings']) : {};

            // 2. Ora recupera 'timeRules' da dentro 'settings'
            final timeRules = settings['timeRules'] != null ? Map<String, dynamic>.from(settings['timeRules']) : {};

            // 3. Ora la lettura funzionerà correttamente
            final String nightDurationStr = timeRules['night'] ?? "2m";
            
            final bool isHost = (adminId == widget.uid);

            // Navigazione Automatica
            if (currentState == 'night_actions' && !_hasNavigatedToAction) {
              _hasNavigatedToAction = true;
              
              final myData = playersMap[widget.uid];
              // Controllo sicuro se è una mappa
              final Map<String, dynamic> playerMap = (myData is Map) ? Map<String, dynamic>.from(myData) : {};
              
              final String myRole = playerMap['role'] ?? 'Farmer'; 
              final bool isAlive = playerMap['alive'] == true; 
              
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Widget targetPage;

                if (!isAlive) {
                  targetPage = DeadRoleRevealScreen(roomId: widget.roomId, uid: widget.uid);
                } else {
                  switch (myRole) {
                    case 'Werewolf': targetPage = WerewolfWakeUpScreen(roomId: widget.roomId, uid: widget.uid); break;
                    case 'Seer': targetPage = SeerWakeUpScreen(roomId: widget.roomId, uid: widget.uid); break;
                    case 'Doctor': targetPage = DoctorWakeUpScreen(roomId: widget.roomId, uid: widget.uid); break;
                    case 'Medium': targetPage = MediumWakeUpScreen(roomId: widget.roomId, uid: widget.uid); break;
                    case 'Spectator': targetPage = SpectatorFormScreeNight(roomId: widget.roomId, uid: widget.uid); break;
                    case 'Farmer': default: targetPage = FarmerWakeUpScreen(roomId: widget.roomId, uid: widget.uid); break;
                  }
                }
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => targetPage));
              });
            }

            // --- CALCOLO GIOCATORI PRESENTI (SOLO VIVI) ---
            int totalAlivePlayers = 0;
            int playersInNight = 0;

            playersMap.forEach((key, value) {
              if (value is Map) {
                final player = Map<String, dynamic>.from(value);
                // Contiamo solo i vivi e non spettatori
                if (player['alive'] == true && player['role'] != 'Spectator') {
                  totalAlivePlayers++;
                  if (player['phaseStatus'] == 'night') {
                    playersInNight++;
                  }
                }
              }
            });

            final int missingPlayers = totalAlivePlayers - playersInNight;
            final bool allPresent = (totalAlivePlayers > 0 && missingPlayers == 0);

            return Stack(
              children: [
                // Stelle di sfondo (Codice invariato)
                Positioned(top: 20, left: 200, child: Icon(Icons.star, color: colorScheme.onPrimary, size: 20)),
                Positioned(top: 60, left: 60, child: Icon(Icons.star, color: colorScheme.onPrimary, size: 18)),
                Positioned(top: 100, right: 30, child: Icon(Icons.star, color: colorScheme.onPrimary, size: 20)),
                
                // Contenuto principale
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6, top: 8),
                          child: Icon(Icons.brightness_3, size: 50, color: colorScheme.onPrimary),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'NIGHT\nTIME',
                              style: textTheme.titleLarge!.copyWith(
                                fontSize: 50,
                                fontWeight: FontWeight.w900,
                                color: colorScheme.onPrimary,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const Spacer(flex: 3),
                    Text(
                      'Good night...',
                      style: textTheme.titleLarge!.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(flex: 5),

                    if (isHost)
                      Column(
                        children: [
                          SizedBox(
                            width: 200,
                            height: 58,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.secondary,
                                foregroundColor: colorScheme.onSecondary,
                                disabledBackgroundColor: Colors.grey,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: allPresent 
                                ? () async {
                                    // 1. Calcola i secondi
                                    int durationSeconds = parseDuration(nightDurationStr); // es. 120
                                    
                                    // 2. Scrive nel DB
                                    await _roomRef.update({
                                      'state': 'night_actions',
                                      'timer': {
                                        'startTime': ServerValue.timestamp, // <--- FONDAMENTALE
                                        'duration': durationSeconds
                                      }
                                    });
                                  } 
                                : null,
                              child: Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSecondary,
                                ),
                              ),
                            ),
                          ),
                          if (!allPresent)
                            Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Text(
                                "Waiting for $missingPlayers players...",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontStyle: FontStyle.italic
                                ),
                              ),
                            )
                        ],
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: Text(
                          "Waiting for the host...",
                          style: TextStyle(
                            fontSize: 20,
                            color: colorScheme.onPrimary,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                    const Spacer(flex: 1),
                  ],
                ),
              ],
            );
          }
        ),
      )
    );
  }
}