import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import '../functions/night_timer.dart';
import 'medium_action_reveal.dart';
import 'return_to_sleep_screen.dart'; 

class MediumWakeUpScreen extends StatefulWidget {
  final String roomId;
  final String uid;

  const MediumWakeUpScreen({super.key, required this.roomId, required this.uid});

  @override
  State<MediumWakeUpScreen> createState() => _MediumWakeUpScreenState();
}

class _MediumWakeUpScreenState extends State<MediumWakeUpScreen> {
  late DatabaseReference _roomRef;
  StreamSubscription<DatabaseEvent>? _playersSubscription;
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  Map<String, dynamic>? _playersData;
  String? selectedPlayerUid;
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: kDatabaseUrl).ref("rooms/${widget.roomId}");
    
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
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Room closed."), backgroundColor: Colors.red));
      }
    });
  }

  // --- LOGICA TIMER MODIFICATA ---
  void _handleTimerEnd() {
    if (_isConfirmed) return;
    
    // Nessuna scelta randomica o conferma. Si passa direttamente oltre.
    _skipAction();
  }

  @override
  void dispose() {
    _playersSubscription?.cancel();
    _roomSubscription?.cancel();
    super.dispose();
  }

  void _confirmAction() {
    if (selectedPlayerUid != null) {
      setState(() => _isConfirmed = true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MediumActionReveal(
            roomId: widget.roomId, 
            uid: widget.uid, 
            targetUid: selectedPlayerUid!
          ),
        ),
      );
    }
  }

  void _skipAction() {
    setState(() => _isConfirmed = true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GoBackToSleepScreen(
          roomId: widget.roomId, 
          uid: widget.uid
        ),
      ),
    );
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
          leading: Builder(builder: (ctx) => IconButton(icon: Icon(Icons.menu_book, color: colorScheme.onPrimary), onPressed: () => scaffoldKey.currentState?.openDrawer())), 
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
                
                // Timer con colore fisso VIOLA (Medium)
                NightTimerWidget(
                  roomId: widget.roomId, 
                  uid: widget.uid,
                  onTimerEnd: _handleTimerEnd,
                  fixedRole: 'Medium', 
                ),
                
                const SizedBox(height: 40),
                Stack(
                  children: [
                    Positioned(top: 6, child: Text('MEDIUM', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, foreground: Paint()..color = const Color(0xFF9A5EA8), letterSpacing: 1), textAlign: TextAlign.center)),
                    Text('MEDIUM', style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: colorScheme.onPrimary, letterSpacing: 2), textAlign: TextAlign.center),
                  ],
                ),
                const SizedBox(height: 10),
                Text('wake up!', style: textTheme.titleLarge!.copyWith(fontSize: 40, fontWeight: FontWeight.w700, color: colorScheme.onPrimary), textAlign: TextAlign.center),
                const SizedBox(height: 30),
                Text('Whose spirit do you want to contact tonight?', style: textTheme.titleMedium!.copyWith(fontSize: 30, fontWeight: FontWeight.w500, color: colorScheme.onPrimary), textAlign: TextAlign.center),
                const SizedBox(height: 40),

                Expanded(
                  child: _playersData == null 
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : Builder(
                    builder: (context) {
                      final List<Map<String, dynamic>> targetList = [];
                      _playersData!.forEach((key, value) {
                        if (value is Map && value['alive'] == false) {
                          targetList.add({"uid": key, "name": value['name']});
                        }
                      });

                      final bool noDeadPlayers = targetList.isEmpty;

                      return Column(
                        children: [
                          Expanded(
                            child: noDeadPlayers 
                            ? Center(
                                child: Text(
                                  "No spirits available to contact...\n(No dead players yet)", 
                                  style: textTheme.titleMedium!.copyWith(color: Colors.white70, fontStyle: FontStyle.italic),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                itemCount: targetList.length,
                                itemBuilder: (context, index) {
                                  final player = targetList[index];
                                  final isSelected = selectedPlayerUid == player['uid'];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isSelected ? const Color(0xFF9A5EA8) : colorScheme.secondary,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      onPressed: () => setState(() => selectedPlayerUid = player['uid']),
                                      child: Text(player['name'], style: textTheme.titleMedium!.copyWith(color: isSelected ? colorScheme.secondary : colorScheme.onSecondary, fontSize: 22)),
                                    ),
                                  );
                                },
                              ),
                          ),

                          const SizedBox(height: 20),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (noDeadPlayers || selectedPlayerUid != null) ? colorScheme.secondary : Colors.grey, 
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 25)
                            ),
                            onPressed: (noDeadPlayers || (selectedPlayerUid != null && !_isConfirmed)) 
                                ? (noDeadPlayers ? _skipAction : _confirmAction) 
                                : null,
                            child: Text(
                              noDeadPlayers ? 'Skip' : 'Confirm', 
                              style: textTheme.titleMedium!.copyWith(fontSize: 24, color: colorScheme.onSecondary)
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      )
    );
  }
}