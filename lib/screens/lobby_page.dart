import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'intro_game_page.dart';
import 'classic/classic_intro_page.dart';
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

  Future<void> _selectNarrator(String targetUid) async {
    final snapshot = await _roomRef.child("narratorId").get();
    if (snapshot.value == targetUid) {
      await _roomRef.child("narratorId").remove();
    } else {
      await _roomRef.child("narratorId").set(targetUid);
    }
  }

  Future<void> _startGame() async {
    final snapshot = await _roomRef.get();
    if (!snapshot.exists) return;
    final data = snapshot.value as Map;
    final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
    final settings = Map<String, dynamic>.from(data['settings'] ?? {});
    final gameRules = Map<String, dynamic>.from(settings['gameRules'] ?? {});
    final bool isClassic = settings['gameMode'] == 'classic';
    final String? narratorId = data['narratorId']?.toString();
    
    final playerEntries = playersMap.entries.toList();
    final activePlayers = playerEntries.where((entry) {
      if (entry.value['role'] == 'Spectator') return false;
      if (isClassic && entry.key == narratorId) return false;
      return true;
    }).toList();

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
    if (isClassic && narratorId != null) {
      updates["players/$narratorId/role"] = "Narrator";
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
            final settings = Map<String, dynamic>.from(roomData['settings'] ?? {});
            final bool isClassic = settings['gameMode'] == 'classic';
            final String? narratorId = roomData['narratorId']?.toString();
            
            if (gameState == 'playing' && !_hasNavigatedToGame) {
              _hasNavigatedToGame = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (isClassic) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => ClassicIntroPage(roomId: widget.roomId, uid: widget.uid))
                  );
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => IntroGamePage(roomId: widget.roomId, uid: widget.uid))
                  );
                }
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
            
            // --- CONDIZIONE COMPLETA ---
            // 1. Tutti pronti
            // 2. La stanza è piena (numero giocatori attuale == numero massimo)
            // 3. Se Classic, un narratore deve essere selezionato
            final bool narratorSelected = !isClassic || (narratorId != null && playersMap.containsKey(narratorId));
            final bool canStartGame = allReady && (playerCount == maxPlayers) && narratorSelected;

            return SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isClassic ? const Color(0xFFD4AF37) : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isClassic ? "Classic Game" : "Standard Game",
                      style: TextStyle(
                        color: isClassic ? Colors.black : Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  ),

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

                  if (isClassic)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mic, color: Color(0xFFD4AF37), size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              narratorId == null
                                  ? (amIAdmin
                                      ? "Select a Narrator: tap the mic next to a player"
                                      : "Waiting for host to select the Narrator...")
                                  : "Narrator: ${playersMap[narratorId]?['name'] ?? 'Unknown'}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

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
                        final isNarrator = isClassic && (player['uid'] == narratorId);

                        return Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: isNarrator
                                ? const Color(0xFFFFF4D0)
                                : Theme.of(context).colorScheme.secondary,
                            borderRadius: BorderRadius.circular(20),
                            border: isNarrator
                                ? Border.all(color: const Color(0xFFD4AF37), width: 3)
                                : (isMe ? Border.all(color: Colors.grey, width: 2) : null),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isNarrator ? const Color(0xFFD4AF37) : Colors.grey,
                                child: Icon(
                                  isNarrator
                                      ? Icons.mic
                                      : (isSpectator ? Icons.visibility : Icons.person),
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      player['name'],
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    if (isNarrator)
                                      const Text(
                                        "Narrator",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    else if (isSpectator)
                                      Text(
                                        "(Spectator)",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.primary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              if (isClassic && amIAdmin && !isSpectator)
                                IconButton(
                                  icon: Icon(
                                    isNarrator ? Icons.mic : Icons.mic_none,
                                    color: isNarrator ? const Color(0xFF8B5A00) : Colors.grey[700],
                                    size: 26,
                                  ),
                                  tooltip: isNarrator ? "Remove Narrator" : "Set as Narrator",
                                  onPressed: () => _selectNarrator(player['uid']),
                                ),

                              InkWell(
                                onTap: isMe ? () => _toggleReady(player['isReady']) : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

                  const Spacer(flex: 1),

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
                              (!narratorSelected)
                                  ? "Please select a Narrator to start the game"
                                  : (!amIReady)
                                      ? "Tap (Not Ready) to toggle it when you're ready"
                                      : (playerCount < maxPlayers)
                                          ? "Waiting for players ($playerCount/$maxPlayers)..."
                                          : "Waiting for everyone to be ready...",
                              style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    )
                  else
                    Text(
                      (!narratorSelected)
                          ? "Waiting for host to select a Narrator..."
                          : (!amIReady)
                              ? "Tap (Not Ready) to toggle it when you're ready"
                              : "Waiting for host to start...",
                      style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
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