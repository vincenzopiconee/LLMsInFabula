import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import '../functions/night_timer.dart';
import 'return_to_sleep_screen.dart';

class SeerActionReveal extends StatefulWidget {
  final String roomId;
  final String uid;
  final String targetUid;

  const SeerActionReveal({
    super.key,
    required this.roomId,
    required this.uid,
    required this.targetUid,
  });

  @override
  State<SeerActionReveal> createState() => _SeerActionRevealState();
}

class _SeerActionRevealState extends State<SeerActionReveal> {
  late DatabaseReference _roomRef;

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
              icon: Icon(Icons.close, color: colorScheme.onPrimary),
              onPressed: () => handleExit(context: context, roomRef: _roomRef, uid: widget.uid),
            ),
          ],
        ),
        body: FutureBuilder(
          future: _roomRef.child("players/${widget.targetUid}").get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final targetData = snapshot.data!.value as Map?;
            final targetRole = targetData?['role'] ?? "Unknown";
            final targetName = targetData?['name'] ?? "Unknown";

            // LOGICA VEGGENTE: Controllo solo se è Lupo o No
            final bool isWerewolf = (targetRole == 'Werewolf');

            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  NightTimerWidget(roomId: widget.roomId, uid: widget.uid),

                  const Spacer(flex: 1),
                  
                  Stack(
                    children: [
                      Positioned(top: 6, child: Text('SEER', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, foreground: Paint()..color = const Color(0xFF166AF1), letterSpacing: 1), textAlign: TextAlign.center)),
                      Text('SEER', style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: colorScheme.onPrimary, letterSpacing: 2), textAlign: TextAlign.center),
                    ],
                  ),
                  
                  const Spacer(flex: 2),
                  
                  Text('You discover that\n$targetName is:', style: textTheme.titleLarge!.copyWith(fontSize: 25, color: colorScheme.onPrimary), textAlign: TextAlign.center),
                  
                  const SizedBox(height: 40),

                  // RIVELAZIONE CONDIZIONALE
                  if (isWerewolf)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 5,
                          child: Text(
                            "WEREWOLF",
                            style: TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.w900,
                              foreground: Paint()..color = const Color(0xFF8B0000), // Rosso Lupo Sfondo
                              letterSpacing: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Text(
                          "WEREWOLF",
                          style: TextStyle(
                            fontSize: 49,
                            fontWeight: FontWeight.w900,
                            color: colorScheme.onPrimary, // Bianco sopra
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  else
                    Text(
                      "NOT A WEREWOLF",
                      style: textTheme.titleLarge!.copyWith(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                  const Spacer(flex: 3),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 25)),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GoBackToSleepScreen(roomId: widget.roomId, uid: widget.uid),
                        ),
                      );
                    },
                    child: Text('Continue', style: textTheme.titleMedium!.copyWith(fontSize: 24, color: colorScheme.onSecondary)),
                  ),
                  const Spacer(flex: 1),        
                ],
              ),
            );
          },
        ),
      )
    );
  }
}