import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import 'daytime_page.dart'; 

class SpectatorFormScreeNight extends StatefulWidget {
  final String roomId;
  final String uid;
  
  const SpectatorFormScreeNight({
    super.key, 
    required this.roomId, 
    required this.uid
    });

  @override
  State<SpectatorFormScreeNight> createState() => _SpectatorFormScreenState();
}

class _SpectatorFormScreenState extends State<SpectatorFormScreeNight> {
  late DatabaseReference _roomRef;
  bool _hasNavigated = false; 

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
    final colorScheme = Theme.of(context).colorScheme;
    
    // Ordine di visualizzazione preferito
    final allRolesOrder = ['Werewolf', 'Medium', 'Seer', 'Doctor', 'Farmer', 'Dead'];
    
    final roleColors = {
      'Werewolf': const Color(0xFF8B0000),
      'Medium': const Color(0xFF9A5EA8),
      'Seer': const Color(0xFF166AF1),
      'Doctor': const Color(0xFF5A8920),
      'Farmer': const Color.fromARGB(255, 141, 134, 29),
      'Dead': Colors.grey,
    };

    return PopScope(
      canPop: false,
      child: Scaffold(
        key: scaffoldKey,
        drawer: const RoleRulesDrawer(),
        backgroundColor: colorScheme.primary, // Notte -> Primary color (scuro)
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 150,
          leading: RoleGuideDrawerButton(
            color: colorScheme.onPrimary,
            scaffoldKey: scaffoldKey,
          ), 
          actions: [
            IconButton(
              icon: Icon(Icons.close, color: colorScheme.onPrimary),
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
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final data = snapshot.data!.snapshot.value as Map;
            final String currentState = data['state'] ?? '';
            final playersMap = Map<String, dynamic>.from(data['players'] ?? {});

            // Navigazione Automatica verso il Giorno
            if (currentState == 'day_phase' && !_hasNavigated) {
              _hasNavigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(
                    builder: (_) => DayTimeScreen(
                      roomId: widget.roomId, 
                      uid: widget.uid
                    )
                  )
                );
              });
            }

            // --- RAGGRUPPAMENTO GIOCATORI ---
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

                // Aggiungi ai vivi (se vivo) o alla lista specifica del ruolo
                if (rolePlayers.containsKey(role)) {
                  rolePlayers[role]!.add(displayName);
                }

                // Aggiungi ai morti (se morto)
                if (!isAlive) {
                  rolePlayers['Dead']!.add("$name ($role)");
                }
              }
            });

            // --- FILTRO DINAMICO ---
            // Mostra solo i ruoli che hanno almeno un giocatore nella lista
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
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: colorScheme.onPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.remove_red_eye, size: 40, color: colorScheme.primary),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Text(
                            'SPECTATOR',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onPrimary,
                              letterSpacing: 1.3,
                              shadows: [
                                Shadow(offset: Offset(2, 4), color: Colors.black26, blurRadius: 4)
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
                                  title: RoleTitleStack(
                                    text: role,
                                    color: color,
                                    fontSize: 35,
                                  ),
                                  iconColor: color,
                                  collapsedIconColor: color,
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: EdgeInsets.zero,
                                  children: [
                                      Column(
                                        children: rolePlayers[role]!
                                            .map((p) => Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              child: Center(
                                                child: Text(
                                                  p,
                                                  style: TextStyle(
                                                    fontSize: 22,
                                                    color: colorScheme.onPrimary,
                                                  ),
                                                ),
                                              ),
                                            ))
                                            .toList(),
                                      ),
                                  ],
                                ),
                              ),
                              // Mostra il divisore solo se non è l'ultimo elemento
                              if (idx < activeRoles.length - 1) Divider(color: colorScheme.secondary, thickness: 2),
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

  const RoleTitleStack({
    required this.text,
    required this.color,
    required this.fontSize,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned(
          top: 4,
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 2,
              fontFamily: Theme.of(context).textTheme.titleLarge?.fontFamily,
            ),
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: colorScheme.secondary,
            letterSpacing: 2,
            fontFamily: Theme.of(context).textTheme.titleLarge?.fontFamily,
          ),
        ),
      ],
    );
  }
}