import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import 'recap_night_page.dart';

class DayTimeScreen extends StatefulWidget {
  final String roomId;
  final String uid;

  const DayTimeScreen({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<DayTimeScreen> createState() => _DayTimeScreenState();
}

class _DayTimeScreenState extends State<DayTimeScreen> {
  late DatabaseReference _roomRef;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");
    
    // Resetto lo stato di fase per i giocatori
    _roomRef.child("players/${widget.uid}/phaseStatus").set("day");
  }

  /// Funzione complessa: Calcola i risultati della notte
  Future<void> _calculateNightResults() async {
    final snapshot = await _roomRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.value as Map;
    final nightActions = data['night_actions'] as Map?;

    String? victimId;
    String? protectedId;

    // 1. CONTEGGIO VOTI LUPI
    if (nightActions != null && nightActions['werewolves'] != null) {
      final votesMap = Map<String, dynamic>.from(nightActions['werewolves']);
      final Map<String, int> voteCounts = {};

      votesMap.forEach((voterId, targetId) {
        voteCounts[targetId] = (voteCounts[targetId] ?? 0) + 1;
      });

      // Trova chi ha più voti
      int maxVotes = 0;
      voteCounts.forEach((targetId, count) {
        if (count > maxVotes) {
          maxVotes = count;
          victimId = targetId;
        }
      });
      // Nota: In caso di pareggio, qui prende l'ultimo iterato. 
      // Si può raffinare con logiche di pareggio (es. random o nessuno muore).
    }

    // 2. CONTROLLO DOTTORE
    if (nightActions != null && nightActions['doctor'] != null) {
      final doctorActions = Map<String, dynamic>.from(nightActions['doctor']);
      // Prendiamo il primo (o unico) dottore che ha agito
      if (doctorActions.isNotEmpty) {
        protectedId = doctorActions.values.first;
      }
    }

    // 3. APPLICAZIONE MORTE
    String resultMessage = "nobody";
    
    if (victimId != null) {
      if (victimId == protectedId) {
        // Il giocatore è stato salvato! Nessuno muore.
        resultMessage = "saved";
      } else {
        // Il giocatore muore
        await _roomRef.child("players/$victimId/alive").set(false);
        resultMessage = victimId!;
      }
    }

    // 4. SALVATAGGIO RISULTATO E CAMBIO STATO
    // Salviamo chi è morto (o 'saved' o 'nobody') per mostrarlo nel Recap
    await _roomRef.update({
      "night_result": resultMessage,
      "state": "recap_night"
    });
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
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.menu_book, color: colorScheme.onSecondary),
              onPressed: () {
                scaffoldKey.currentState?.openDrawer();
              },
            ),
          ), 
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
            if (snapshot.hasError) return const Center(child: Text("Loading error"));
            
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
            final adminId = data['adminId'];
            final String currentState = data['state'] ?? '';
            final bool isHost = (adminId == widget.uid);

            // --- LOGICA DI NAVIGAZIONE ---
            if (currentState == 'recap_night' && !_hasNavigated) {
              _hasNavigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecapNightPage(
                      roomId: widget.roomId,
                      uid: widget.uid,
                    ),
                  ),
                );
              });
            }
            // -----------------------------

            return Stack(
              children: [
                // Sfondo decorativo: cielo, sole, nuvole, colline
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.secondary,                 // azzurrino chiaro
                          colorScheme.secondary,
                        ],
                      ),
                    ),
                  ),
                ),

                // Sole grande in alto a destra
                /*Positioned(
                  top: 80,
                  right: 40,
                  child: Icon(
                    Icons.wb_sunny_rounded,
                    size: 70,
                    color: const Color(0xFFFFD54F),
                  ),
                ),*/

                // Nuvole sparse
                Positioned(
                  top: 140,
                  left: 30,
                  child: Icon(
                    Icons.cloud_rounded,
                    size: 55,
                    color: const Color.fromARGB(255, 208, 207, 207),
                  ),
                ),
                Positioned(
                  top: 220,
                  right: 20,
                  child: Icon(
                    Icons.cloud_rounded,
                    size: 65,
                    color: const Color.fromARGB(255, 208, 207, 207),
                  ),
                ),
                Positioned(
                  top: 260,
                  left: 60,
                  child: Icon(
                    Icons.cloud_rounded,
                    size: 45,
                    color: const Color.fromARGB(255, 208, 207, 207),
                  ),
                ),

                // Colline in basso
                Positioned(
                  left: -60,
                  right: -60,
                  bottom: -40,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(200),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.elliptical(260, 120),
                      ),
                    ),
                  ),
                ),

                // Casette sul profilo della collina (villaggio)
                Positioned(
                  bottom: 131,
                  left: 130,
                  child: Icon(
                    Icons.home_rounded,
                    size: 32,
                    color: colorScheme.onSecondary,
                  ),
                ),
                Positioned(
                  bottom: 135,
                  left: 170,
                  child: Icon(
                    Icons.house_rounded,
                    size: 26,
                    color: colorScheme.onSecondary,
                  ),
                ),
                Positioned(
                  bottom: 135,
                  left: 200,
                  child: Icon(
                    Icons.home_rounded,
                    size: 30,
                    color: colorScheme.onSecondary,
                  ),
                ),
                Positioned(
                  bottom: 133,
                  right: 150,
                  child: Icon(
                    Icons.house_rounded,
                    size: 28,
                    color: colorScheme.onSecondary,
                  ),
                ),



                // --- Contenuto principale ---
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 1),

                    // Intestazione DAY TIME
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Icon(Icons.sunny, size: 70, color: const Color(0xFFFFD54F)),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 30, right: 40),
                              child: Icon(Icons.cloud, size: 70, color: const Color.fromARGB(255, 208, 207, 207)), 
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'DAY\nTIME',
                              style: textTheme.titleLarge!.copyWith(
                                fontSize: 50,
                                fontWeight: FontWeight.w900,
                                color: colorScheme.onSecondary,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 65),

                    Text(
                      'Wakey Wakey!',
                      style: textTheme.titleLarge!.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const Spacer(flex: 2),

                    Text(
                      '*someone may be dead',
                      style: textTheme.titleLarge!.copyWith(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const Spacer(flex: 4),

                    // --- LOGICA BOTTONE CONTINUE (ADMIN) ---
                    if (isHost)
                      SizedBox(
                        width: 200,
                        height: 58,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _calculateNightResults, // Chiama la funzione di calcolo
                          child: Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
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

                    const SizedBox(height: 40),
                  ],
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}