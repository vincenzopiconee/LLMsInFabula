import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import '../functions/night_timer.dart';
import 'return_to_sleep_screen.dart';

class MediumActionReveal extends StatefulWidget {
  final String roomId;
  final String uid;
  final String targetUid;

  const MediumActionReveal({
    super.key,
    required this.roomId,
    required this.uid,
    required this.targetUid,
  });

  @override
  State<MediumActionReveal> createState() => _MediumActionRevealState();
}

class _MediumActionRevealState extends State<MediumActionReveal> {
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

            return Column(
              children: [
                const SizedBox(height: 24),

                NightTimerWidget(roomId: widget.roomId, uid: widget.uid),

                const Spacer(flex: 1),
                Stack(
                  children: [
                    Positioned(top: 6, child: Text('MEDIUM', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, foreground: Paint()..color = const Color(0xFF9A5EA8), letterSpacing: 1), textAlign: TextAlign.center)),
                    Text('MEDIUM', style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: colorScheme.onPrimary, letterSpacing: 2), textAlign: TextAlign.center),
                  ],
                ),

                const Spacer(flex: 2),
                Text('The spirit of $targetName\nreveals they were a:', style: textTheme.titleLarge!.copyWith(fontSize: 25, color: colorScheme.onPrimary), textAlign: TextAlign.center),
                const SizedBox(height: 40),

                // Rivelazione
                Text(
                  targetRole.toUpperCase(),
                  style: textTheme.titleLarge!.copyWith(
                    fontSize: 50,
                    color: const Color(0xFF9A5EA8),
                    fontWeight: FontWeight.bold,
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
            );
          },
        ),
      )
    );
  }
}