import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import '../functions/night_timer.dart';
import 'return_to_sleep_screen.dart';

class FarmerWakeUpScreen extends StatefulWidget {
  final String roomId;
  final String uid;

  const FarmerWakeUpScreen({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<FarmerWakeUpScreen> createState() => _FarmerWakeUpScreenState();
}

class _FarmerWakeUpScreenState extends State<FarmerWakeUpScreen> {
  late DatabaseReference _roomRef;
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  
  // Controller per mantenere la posizione dello scroll
  final ScrollController _scrollController = ScrollController();
  
  String? selectedAction;
  String? actionDescription;
  bool _showResult = false;

  final List<String> actions = [
    'Return to sleep',
    'Drink milk',
    'Eat a cookie',
    'Count sheep',
    'Feed the chickens',
    'Pray for protection',
    'Look at the stars',
    'Whisper a folk song',
  ];

  final Map<String, String> actionDescriptions = {
    'Return to sleep':
        'You pull the blanket over your head and try to ignore the noise. If danger is coming, you will face it in the morning.',
    'Drink milk':
        'You pour yourself a glass of fresh milk. The warmth calms your nerves and the strange sound fades into the distance.',
    'Eat a cookie':
        'You grab a cookie from the table. The crunch and sweetness distract you just enough to forget the noise… for now.',
    'Count sheep':
        'You start counting sheep jumping over the fence. One, two, three… soon your eyes grow heavy again.',
    'Feed the chickens':
        'You step outside and check on the chickens. Everything seems quiet, but you cannot shake the feeling of being watched.',
    'Pray for protection':
        'You close your eyes and whisper a simple prayer. The night feels a little less cold, as if someone heard you.',
    'Look at the stars':
        'You look up at the sky. The stars are calm and indifferent, but you feel strangely reassured.',
    'Whisper a folk song':
        'You hum an old folk song your grandparents used to sing. The melody fills the room and pushes the fear away.',
  };

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");
    _listenForRoomDeletion();
  }

  void _listenForRoomDeletion() {
    _roomSubscription = _roomRef.onValue.listen((event) {
      if (event.snapshot.value == null) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("The lobby has been closed by the host."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  // --- LOGICA TIMER: Navigazione forzata ---
  void _handleTimerEnd() {
    // Se il tempo scade, andiamo direttamente a dormire ignorando la scelta
    _confirmAction(); 
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _scrollController.dispose(); 
    super.dispose();
  }

  void _confirmAction() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GoBackToSleepScreen(
          roomId: widget.roomId,
          uid: widget.uid,
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
              icon: Icon(Icons.close, color: colorScheme.onPrimary, size: 28),
              onPressed: () {
                handleExit(context: context, roomRef: _roomRef, uid: widget.uid);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // --- AGGIORNATO: Timer con Ruolo Fisso e Callback ---
                NightTimerWidget(
                  roomId: widget.roomId, 
                  uid: widget.uid,
                  onTimerEnd: _handleTimerEnd,
                  fixedRole: 'Farmer', // Forza il colore Giallo/Oro
                ),

                const SizedBox(height: 10),

                // Titolo Farmer
                Stack(
                  children: [
                    Positioned(
                      top: 4,
                      child: Text(
                        'FARMER',
                        style: TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          foreground: Paint()..color = const Color.fromARGB(255, 141, 134, 29),
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Text(
                      'FARMER',
                      style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: colorScheme.onPrimary, letterSpacing: 2),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                
                
                Text(
                  'wake up!',
                  style: textTheme.titleLarge!.copyWith(fontSize: 40, fontWeight: FontWeight.w700, color: colorScheme.onPrimary, height: 1.2),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                Text(
                  'You heard a strange noise, what do you want to do?',
                  style: textTheme.titleMedium!.copyWith(fontSize: 30, fontWeight: FontWeight.w500, color: colorScheme.onPrimary, height: 1.3),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                if (!_showResult) ...[
                  // STEP 1: lista azioni + bottone Confirm
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      thickness: 6,
                      radius: const Radius.circular(10),
                      controller: _scrollController,
                      child: ListView.builder(
                        controller: _scrollController,
                        key: const PageStorageKey('farmer_actions_list'),
                        itemCount: actions.length,
                        itemBuilder: (context, index) {
                          final action = actions[index];
                          final isSelected = selectedAction == action;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? const Color.fromARGB(255, 141, 134, 29)
                                    : colorScheme.secondary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () {
                                setState(() {
                                  selectedAction = action;
                                });
                              },
                              child: Text(
                                action,
                                style: textTheme.titleMedium!.copyWith(
                                  fontSize: 22,
                                  color: isSelected
                                      ? colorScheme.secondary
                                      : colorScheme.onSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.secondary,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 25),
                      ),
                      onPressed: selectedAction == null
                          ? null
                          : () {
                              setState(() {
                                actionDescription =
                                    actionDescriptions[selectedAction]!;
                                _showResult = true;
                              });
                            },
                      child: Text(
                        'Confirm',
                        style: textTheme.titleMedium!.copyWith(
                          fontSize: 24,
                          color: colorScheme.onSecondary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ] else ...[
                  // STEP 2: solo descrizione + Continue
                  const Spacer(),
                  if (actionDescription != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        actionDescription!,
                        style: textTheme.bodyMedium!.copyWith(
                          fontSize: 20,
                          color: colorScheme.onSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.secondary,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 25),
                      ),
                      onPressed: _confirmAction,
                      child: Text(
                        'Continue',
                        style: textTheme.titleMedium!.copyWith(
                          fontSize: 24,
                          color: colorScheme.onSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ],
            ),
          ),
        ),
      )
    );
  }
}