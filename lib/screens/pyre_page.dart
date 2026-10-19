import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import 'pyre_session_page.dart';

class PyreScreen extends StatefulWidget {
  final String roomId;
  final String uid;

  const PyreScreen({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<PyreScreen> createState() => _PyreScreenState();
}

class _PyreScreenState extends State<PyreScreen> {
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
        body: SafeArea(
          child: StreamBuilder(
            stream: _roomRef.onValue,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.snapshot.value == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) onRoomClosed(context);
                });
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Center(child: CircularProgressIndicator());
              }
          
              final data = snapshot.data!.snapshot.value as Map;
              final String currentState = data['state'] ?? '';
              final String adminId = data['adminId'] ?? '';
              final bool isHost = (widget.uid == adminId);
          
              // LOGICA NAVIGAZIONE
              if (currentState == 'pyre_session' && !_hasNavigated) {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => PyreSessionPage(roomId: widget.roomId, uid: widget.uid)),
                  );
                });
              }
          
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(flex: 1),

                        // Titolo adattivo
                        Flexible(
                          flex: 4,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  top: 6,
                                  child: Text(
                                    'PYRE',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 57, 
                                      fontWeight: FontWeight.w900, 
                                      foreground: Paint()..color = const Color.fromARGB(255, 205, 7, 7), 
                                      letterSpacing: 1
                                    ),
                                  ),
                                ),
                                Text(
                                  'PYRE',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 56, 
                                    fontWeight: FontWeight.w900, 
                                    foreground: Paint()..color = const Color.fromARGB(255, 239, 151, 8), 
                                    letterSpacing: 2
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
              
                        const Spacer(flex: 1),
              
                        // Immagine
                        Flexible(
                          flex: 5, 
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle, 
                                border: Border.all(color: colorScheme.secondary, width: 3)
                              ),
                              child: const Image(
                                image: AssetImage('assets/images/pyre.png'),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
              
                        const Spacer(flex: 1),
              
                        // Primo testo
                        Flexible(
                          flex: 4,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              width: 550, 
                              decoration: BoxDecoration(
                                border: Border.all(color: colorScheme.onSecondary, width: 2), 
                                borderRadius: BorderRadius.circular(16)
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'It\'s a tie — the village demands a final vote. Decide who must leave once and for all.', 
                                style: textTheme.titleLarge!.copyWith(
                                  fontSize: 22, 
                                  fontWeight: FontWeight.w700, 
                                  color: colorScheme.onSecondary
                                ), 
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
              
                        const Spacer(flex: 1),
              
                        // Secondo testo
                        Flexible(
                          flex: 3,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              width: 500,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: colorScheme.onSecondary, width: 2), 
                                borderRadius: BorderRadius.circular(20)
                              ),
                              child: Text(
                                'If no decision is made, no one will be exiled tonight.', 
                                style: textTheme.titleLarge!.copyWith(
                                  fontSize: 19, 
                                  fontWeight: FontWeight.w700, 
                                  color: colorScheme.onSecondary
                                ), 
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        
                        const Spacer(flex: 2),
              
                        // Bottone Host Continue / Waiting for host
                        if (isHost)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 25),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              await _roomRef.update({
                                'state': 'pyre_session',
                                'timer': {
                                  'startTime': ServerValue.timestamp,
                                  'duration': 60,
                                }
                              });
                            },
                            child: Text(
                              'Continue',
                              textAlign: TextAlign.center,
                              style: textTheme.titleMedium!.copyWith(
                                fontSize: 24,
                                color: colorScheme.onPrimary, 
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Text(
                            "Waiting for the host...",
                            style: TextStyle(
                              color: colorScheme.onSecondary,
                              fontSize: 20,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),
              );
            }
          ),
        )
      )
    );
  }
}