import 'dart:async';
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import '../functions/night_timer.dart';
import 'return_to_sleep_screen.dart'; 

class WerewolfWakeUpScreen extends StatefulWidget {
  final String roomId;
  final String uid;

  const WerewolfWakeUpScreen({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<WerewolfWakeUpScreen> createState() => _WerewolfWakeUpScreenState();
}

class _WerewolfWakeUpScreenState extends State<WerewolfWakeUpScreen> {
  late DatabaseReference _roomRef;
  
  StreamSubscription<DatabaseEvent>? _playersSubscription;
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  Map<String, dynamic>? _playersData;
  
  String? selectedPlayerUid;
  bool _isVoteConfirmed = false;

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");
    
    _playersSubscription = _roomRef.child("players").onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        setState(() {
          _playersData = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });
    
    _listenForRoomDeletion();
  }

  void _listenForRoomDeletion() {
    _roomSubscription = _roomRef.onValue.listen((event) {
      if (event.snapshot.value == null && mounted) {
        _roomSubscription?.cancel();
        onRoomClosed(context);
      }
    });
  }

  void _handleTimerEnd() {
    if (_isVoteConfirmed) return; 

    if (selectedPlayerUid != null) {
      _confirmVote();
    } else {
      if (_playersData != null) {
        final List<String> validTargets = [];
        _playersData!.forEach((key, value) {
          if (value is Map && 
              value['role'] != 'Spectator' && 
              value['role'] != 'Werewolf' && 
              value['alive'] == true) {
            validTargets.add(key);
          }
        });

        if (validTargets.isNotEmpty) {
          final randomUid = validTargets[Random().nextInt(validTargets.length)];
          setState(() => selectedPlayerUid = randomUid);
          _confirmVote();
        } else {
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => GoBackToSleepScreen(roomId: widget.roomId, uid: widget.uid)),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _playersSubscription?.cancel();
    _roomSubscription?.cancel();
    super.dispose();
  }

  Future<void> _confirmVote() async {
    if (selectedPlayerUid == null) return;
    setState(() => _isVoteConfirmed = true);

    await _roomRef.child("night_actions/werewolves/${widget.uid}").set(selectedPlayerUid);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => GoBackToSleepScreen(roomId: widget.roomId, uid: widget.uid)),
      );
    }
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
          leadingWidth: 150,
          leading: RoleGuideDrawerButton(
            color: colorScheme.onPrimary,
            scaffoldKey: scaffoldKey,
          ), 
          actions: [
            IconButton(icon: Icon(Icons.close, color: colorScheme.onPrimary), onPressed: () => handleExit(context: context, roomRef: _roomRef, uid: widget.uid)),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                
                // --- AGGIUNTO fixedRole ---
                NightTimerWidget(
                  roomId: widget.roomId, 
                  uid: widget.uid,
                  onTimerEnd: _handleTimerEnd,
                  fixedRole: 'Werewolf', // Forza il colore Rosso
                ),
                
                const SizedBox(height: 40),
                Stack(
                  children: [
                    Positioned(top: 6, child: Text('WEREWOLVES', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, foreground: Paint()..color = const Color(0xFF8B0000), letterSpacing: 1), textAlign: TextAlign.center)),
                    Text('WEREWOLVES', style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: colorScheme.onPrimary, letterSpacing: 2), textAlign: TextAlign.center),
                  ],
                ),
                const SizedBox(height: 10),
                Text('wake up!', style: textTheme.titleLarge!.copyWith(fontSize: 40, fontWeight: FontWeight.w700, color: colorScheme.onPrimary, height: 1.2), textAlign: TextAlign.center),
                const SizedBox(height: 30),
                Text('Who do you want to kill \nthis night?', style: textTheme.titleMedium!.copyWith(fontSize: 30, fontWeight: FontWeight.w500, color: colorScheme.onPrimary, height: 1.3), textAlign: TextAlign.center),
                const SizedBox(height: 40),

                Expanded(
                  child: _playersData == null
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : Builder(
                          builder: (context) {
                            final List<Map<String, dynamic>> targetList = [];
                            _playersData!.forEach((key, value) {
                              if (value is Map && value['role'] != 'Spectator' && value['role'] != 'Werewolf' && value['alive'] == true) {
                                targetList.add({"uid": key, "name": value['name'] ?? "Unknown"});
                              }
                            });

                            if (targetList.isEmpty) return const Center(child: Text("No targets available.", style: TextStyle(color: Colors.white)));

                            return ListView.builder(
                              itemCount: targetList.length,
                              itemBuilder: (context, index) {
                                final player = targetList[index];
                                final isSelected = selectedPlayerUid == player['uid'];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isSelected ? const Color(0xFF8B0000) : colorScheme.secondary,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    onPressed: _isVoteConfirmed ? null : () => setState(() => selectedPlayerUid = player['uid']),
                                    child: Text(player['name'], style: textTheme.titleMedium!.copyWith(fontSize: 22, color: isSelected ? colorScheme.secondary : colorScheme.onSecondary)),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),

                const SizedBox(height: 20),
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
                    onPressed: (selectedPlayerUid != null && !_isVoteConfirmed) ? _confirmVote : null,
                    child: Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      )
    );
  }
}