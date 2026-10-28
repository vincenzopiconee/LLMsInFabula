import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'intro_game_page.dart';
import '../functions/functions.dart';
import 'dart:math';

const String kDatabaseUrl = 'https://llminfabula-1-default-rtdb.europe-west1.firebasedatabase.app';

class LobbyPage extends StatefulWidget {
  final String roomId;
  final String uid;

  const LobbyPage({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  late DatabaseReference _roomRef;
  bool _hasNavigatedToGame = false;

  @override
  void initState() {
    super.initState();
    resetExitFlags();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");
  }

  Future<void> _callHandleExit() async {
    await handleExit(context: context, roomRef: _roomRef, uid: widget.uid);
  }
  
  Future<void> _toggleReady(bool currentStatus) async {
    await _roomRef.child("players/${widget.uid}/isReady").set(!currentStatus);
  }

  Future<void> _startGame() async {
    final snapshot = await _roomRef.get();
    if (!snapshot.exists) return;
    final data = snapshot.value as Map;
    final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
    final gameRules = Map<String, dynamic>.from(data['settings']?['gameRules'] ?? {});
    
    final playerEntries = playersMap.entries.toList();
    final activePlayers = playerEntries.where((entry) => entry.value['role'] != 'Spectator').toList();
    final activePlayerIds = activePlayers.map((e) => e.key).toList();
    final int numActivePlayers = activePlayerIds.length;

    List<String> roleDeck = [];
    if (gameRules['Wolves'] != null) for (int i = 0; i < gameRules['Wolves']; i++) {roleDeck.add("Werewolf");}
    if (gameRules['Doctors'] != null) for (int i = 0; i < gameRules['Doctors']; i++) {roleDeck.add("Doctor");}
    if (gameRules['Seers'] != null) for (int i = 0; i < gameRules['Seers']; i++) {roleDeck.add("Seer");}
    if (gameRules['Medium'] != null) for (int i = 0; i < gameRules['Medium']; i++) {roleDeck.add("Medium");}
    
    while (roleDeck.length < numActivePlayers) {
      roleDeck.add("Farmer");
    }
    if (roleDeck.length > numActivePlayers) roleDeck = roleDeck.sublist(0, numActivePlayers);
    roleDeck.shuffle(Random());

    Map<String, Object?> updates = {};
    for (int i = 0; i < numActivePlayers; i++) {
      updates["players/${activePlayerIds[i]}/role"] = roleDeck[i];
    }
    updates["state"] = "playing"; 
    await _roomRef.update(updates);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.primary,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.secondary),
            onPressed: _callHandleExit,
          ),
          title: const Text("Your Lobby"),
          centerTitle: true,
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

            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

            final roomData = snapshot.data!.snapshot.value as Map;
            final playersMap = roomData['players'] as Map? ?? {};
            final adminId = roomData['adminId'];
            final maxPlayers = roomData['settings']?['maxPlayers'] ?? 8;
            final String? gameState = roomData['state'];
            
            if (gameState == 'playing' && !_hasNavigatedToGame) {
              _hasNavigatedToGame = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => IntroGamePage(roomId: widget.roomId, uid: widget.uid))
                );
              });
            }

            final List<Map<String, dynamic>> playersList = [];
            playersMap.forEach((key, value) {
              playersList.add({
                "uid": key,
                "name": value['name'] ?? "Unknown",
                "isReady": value['isReady'] ?? false,
                "role": value['role'],
              });
            });

            final myPlayerEntry = playersList.firstWhere(
              (p) => p['uid'] == widget.uid,
              orElse: () => {'isReady': false},
            );

            final bool amIReady = myPlayerEntry['isReady'] ?? false;

            final bool amIAdmin = widget.uid == adminId;
            final int playerCount = playersList.length;
            final bool allReady = playersList.isNotEmpty && playersList.every((p) => p['isReady'] == true);
            
            // --- NUOVA CONDIZIONE COMPLETA ---
            // 1. Tutti pronti
            // 2. La stanza è piena (numero giocatori attuale == numero massimo)
            final bool canStartGame = allReady && (playerCount == maxPlayers);

            return SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  
                  Text(
                    "Game Code",
                    style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 25),
                  ),
                  
                  const Spacer(flex: 1),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildCodeBoxes(widget.roomId),
                  ),

                  const Spacer(flex: 1),

                  Row(
                    children: [
                      const SizedBox(width: 30),
                      Text(
                        // Mostra chiaramente quanti mancano
                        "Players ($playerCount/$maxPlayers)",
                        style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 16),
                      ),
                    ],
                  ),
                  
                  const Spacer(flex: 1),

                  Expanded(
                    flex: 15, 
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: playersList.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final player = playersList[index];
                        final isMe = player['uid'] == widget.uid;
                        final isSpectator = player['role'] == 'Spectator';

                        return Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            borderRadius: BorderRadius.circular(20),
                            border: isMe ? Border.all(color: Colors.grey, width: 2) : null,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.grey,
                                child: Icon(isSpectator ? Icons.visibility : Icons.person, color: Colors.black),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      player['name'],
                                      style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.primary),
                                    ),
                                    if (isSpectator)
                                      Text(
                                        "(Spectator)",
                                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic),
                                      ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: isMe ? () => _toggleReady(player['isReady']) : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: player['isReady'] ? Theme.of(context).colorScheme.primary : Colors.grey[400],
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    player['isReady'] ? "Ready" : "Not Ready",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  Spacer(flex:1),

                  if (amIAdmin)
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
                            // --- QUI APPLICHIAMO LA NUOVA CONDIZIONE ---
                            onPressed: canStartGame ? _startGame : null, 
                            child: Text(
                              "Start Game",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSecondary,
                              ),
                            ),
                          ),
                        ),
                        if (!canStartGame)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              (!amIReady)
                                ? "Tap (Not Ready) to toggle it when you're ready" // Se TU non sei pronto
                                : (playerCount < maxPlayers)
                                    ? "Waiting for players ($playerCount/$maxPlayers)..."
                                    : "Waiting for everyone to be ready...",
                              style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    )
                  else
                    Text((!amIReady)
                      ? "Tap (Not Ready) to toggle it when you ready" // Se TU non sei pronto
                      : "Waiting for host to start...",
                      style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)
                    ),
                  const Spacer(flex: 2),
                ],
              ),
            );
          },
        ),
      )
    );
  }

  List<Widget> _buildCodeBoxes(String code) {
    List<Widget> boxes = [];
    for (int i = 0; i < 4; i++) {
      String char = (i < code.length) ? code[i].toUpperCase() : "";
      boxes.add(
        Container(
          width: 60, height: 70,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(12)),
          child: Center(
            child: Text(char, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0B253A))),
          ),
        ),
      );
    }
    return boxes;
  }
}