import 'dart:async';
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import 'package:llm_in_fabula/functions/night_timer.dart';
import 'return_to_sleep_screen.dart';

class DoctorWakeUpScreen extends StatefulWidget {
  final String roomId;
  final String uid;

  const DoctorWakeUpScreen({super.key, required this.roomId, required this.uid});

  @override
  State<DoctorWakeUpScreen> createState() => _DoctorWakeUpScreenState();
}

class _DoctorWakeUpScreenState extends State<DoctorWakeUpScreen> {
  late DatabaseReference _roomRef;
  StreamSubscription<DatabaseEvent>? _playersSubscription;
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  Map<String, dynamic>? _playersData;
  String? selectedPlayerUid;
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");
    
    _playersSubscription = _roomRef.child("players").onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          _playersData = data; 
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

  void _handleTimerEnd() {
    if (_isConfirmed) return; 

    if (selectedPlayerUid != null) {
      _confirmAction();
    } else {
      if (_playersData != null) {
        final List<String> validTargets = [];
        _playersData!.forEach((key, value) {
          if (value is Map && value['role'] != 'Spectator' && value['alive'] == true) {
            validTargets.add(key);
          }
        });

        if (validTargets.isNotEmpty) {
          final randomUid = validTargets[Random().nextInt(validTargets.length)];
          setState(() {
            selectedPlayerUid = randomUid;
          });
          _confirmAction();
        } else {
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GoBackToSleepScreen(roomId: widget.roomId, uid: widget.uid),
            ),
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

  Future<void> _confirmAction() async {
    if (selectedPlayerUid == null) return;
    setState(() => _isConfirmed = true);
    await _roomRef.child("night_actions/doctor/${widget.uid}").set(selectedPlayerUid);
    
    if (mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => GoBackToSleepScreen(roomId: widget.roomId, uid: widget.uid))
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
          leading: Builder(builder: (ctx) => IconButton(icon: Icon(Icons.menu_book, color: colorScheme.onPrimary), onPressed: () => scaffoldKey.currentState?.openDrawer())),         
          actions: [
            IconButton(icon: Icon(Icons.close, color: colorScheme.onPrimary), onPressed: () => handleExit(context: context, roomRef: _roomRef, uid: widget.uid)),
          ],
        ),
        body: _playersData == null
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Builder(
                builder: (context) {
                  final List<Map<String, dynamic>> targetList = [];
                  _playersData!.forEach((key, value) {
                    if (value is Map && value['role'] != 'Spectator' && value['alive'] == true) {
                      targetList.add({"uid": key, "name": value['name']});
                    }
                  });

                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          
                          // --- QUI IL CAMBIAMENTO PRINCIPALE ---
                          NightTimerWidget(
                            roomId: widget.roomId, 
                            uid: widget.uid,
                            onTimerEnd: _handleTimerEnd,
                            fixedRole: 'Doctor', // Forza il colore Verde
                          ),
                          // -------------------------------------
                          
                          const SizedBox(height: 40),
                          Stack(children: [
                            Positioned(top: 6, child: Text('DOCTOR', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, foreground: Paint()..color = const Color(0xFF5A8920), letterSpacing: 1), textAlign: TextAlign.center)), 
                            Text('DOCTOR', style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: colorScheme.onPrimary, letterSpacing: 2), textAlign: TextAlign.center)
                          ]),
                          const SizedBox(height: 10),
                          Text('wake up!', style: textTheme.titleLarge!.copyWith(fontSize: 40, fontWeight: FontWeight.w700, color: colorScheme.onPrimary), textAlign: TextAlign.center),
                          const SizedBox(height: 30),
                          Text('Who do you want to protect tonight?', style: textTheme.titleMedium!.copyWith(fontSize: 30, fontWeight: FontWeight.w500, color: colorScheme.onPrimary), textAlign: TextAlign.center),
                          const SizedBox(height: 40),
                          
                          Expanded(
                            child: ListView.builder(
                              itemCount: targetList.length,
                              itemBuilder: (context, index) {
                                final player = targetList[index];
                                final isSelected = selectedPlayerUid == player['uid'];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isSelected ? const Color(0xFF5A8920) : colorScheme.secondary,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    onPressed: _isConfirmed ? null : () => setState(() => selectedPlayerUid = player['uid']),
                                    child: Text(player['name'], style: textTheme.titleMedium!.copyWith(color: isSelected ? colorScheme.secondary : colorScheme.onSecondary, fontSize: 22)),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: _isConfirmed ? Colors.grey : colorScheme.secondary, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 25)),
                            onPressed: (selectedPlayerUid != null && !_isConfirmed) ? _confirmAction : null,
                            child: Text('Confirm', style: textTheme.titleMedium!.copyWith(fontSize: 24, color: colorScheme.onSecondary)),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  );
                }
              ),
      ),
    );
  }
}