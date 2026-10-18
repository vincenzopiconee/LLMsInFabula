import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import '../functions/night_timer.dart';
import 'daytime_page.dart'; 

class GoBackToSleepScreen extends StatefulWidget {
  final String roomId;
  final String uid;

  const GoBackToSleepScreen({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<GoBackToSleepScreen> createState() => _GoBackToSleepScreenState();
}

class _GoBackToSleepScreenState extends State<GoBackToSleepScreen> {
  late DatabaseReference _roomRef;
  bool _hasNavigated = false; 
  bool _isTransitioning = false; // Evita trigger multipli

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");

    // Segnalo che sono "a letto"
    _roomRef.child("players/${widget.uid}/phaseStatus").set("sleeping");
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
            final playersRaw = data['players'];
            final Map<dynamic, dynamic> playersMap = (playersRaw is Map) ? playersRaw : {};
            final String currentState = data['state'] ?? '';

            // 1. NAVIGAZIONE: Se lo stato cambia in 'day_phase', andiamo tutti al giorno
            if (currentState == 'day_phase' && !_hasNavigated) {
              _hasNavigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DayTimeScreen(
                      roomId: widget.roomId,
                      uid: widget.uid,
                    ),
                  ),
                );
              });
            }

            // 2. CONTEGGIO: Contiamo solo i vivi
            int totalAlivePlayers = 0;
            int sleepingCount = 0;

            playersMap.forEach((key, value) {
              if (value is Map) {
                final player = Map<String, dynamic>.from(value);
                // Contiamo solo i vivi e non spettatori
                if (player['alive'] == true && player['role'] != 'Spectator') {
                  totalAlivePlayers++;
                  if (player['phaseStatus'] == 'sleeping') {
                    sleepingCount++;
                  }
                }
              }
            });

            // 3. LOGICA AUTOMATICA: Se tutti i vivi dormono -> Giorno
            if (totalAlivePlayers > 0 && sleepingCount >= totalAlivePlayers && !_isTransitioning && currentState != 'day_phase') {
              _isTransitioning = true;
              // Eseguiamo l'update (chiunque arrivi per ultimo lo farà scattare)
              Future.microtask(() async {
                await _roomRef.update({'state': 'day_phase'}); 
              });
            }

            return Column(
              children: [
                const SizedBox(height: 24),
                // INSERISCI QUESTO AL SUO POSTO:
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: NightTimerWidget(
                    roomId: widget.roomId,
                    uid: widget.uid,
                    returnedToSleep: true,
                    onTimerEnd: () {
                      // NON FARE NULLA: Siamo già nella pagina di attesa.
                      // Quando tutti arriveranno qui (spinti dal timer nelle altre pagine),
                      // la logica "sleepingCount >= totalAlivePlayers" farà scattare il giorno.
                    },
                  ),
                ),

                const Spacer(flex: 1),

                Text(
                  'Return to sleep',
                  style: textTheme.titleLarge!.copyWith(
                    fontSize: 40,
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold
                  ),
                  textAlign: TextAlign.center
                ),
                const SizedBox(height: 22),
                Text(
                  'and wait for the\nday...',
                  style: textTheme.titleLarge!.copyWith(
                    fontSize: 25,
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.normal
                  ),
                  textAlign: TextAlign.center
                ),

                const Spacer(flex: 1),

                SizedBox(
                  width: 260,
                  height: 260,
                  child: const Center(
                    child: Image(image: AssetImage('assets/images/sleeping.png'), width: 260, height: 260),
                  ),
                ),

                const Spacer(flex: 2),

                // Contatore / Stato (uguale per tutti)
                Column(
                  children: [
                    if (_isTransitioning)
                      const CircularProgressIndicator(color: Colors.white)
                    else
                      Text(
                        "$sleepingCount / $totalAlivePlayers asleep",
                        style: TextStyle(
                          fontSize: 20,
                          color: colorScheme.onPrimary,
                          fontStyle: FontStyle.italic
                        ),
                      ),
                      
                    const SizedBox(height: 10),
                    
                    Text(
                      _isTransitioning ? "Sunrise is coming..." : "Waiting for everyone to sleep...",
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 1),
              ],
            );
          },
        ),
      )
    );
  }
}