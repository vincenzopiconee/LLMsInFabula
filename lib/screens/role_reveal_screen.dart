import 'dart:async';
import 'package:flutter/material.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'nighttime_page.dart';

class RoleRevealScreen extends StatefulWidget {
  final String roleName;
  final String roleImage;
  final String roleDescription;
  final Color roleColor; 
  final String roomId;
  final String uid;

  const RoleRevealScreen({
    super.key,
    required this.roleName,
    required this.roleImage,
    required this.roleDescription,
    required this.roleColor,
    required this.roomId,
    required this.uid,
  });

  @override
  State<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends State<RoleRevealScreen> {
  late DatabaseReference _roomRef;
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  
  // Variabile per gestire lo stato di visibilità
  bool _isRoleRevealed = false;
    
  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");
    _listenForRoomDeletion();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  void _listenForRoomDeletion() {
    _roomSubscription = _roomRef.onValue.listen((event) {
      if (event.snapshot.value == null && mounted) {
        _roomSubscription?.cancel();
        onRoomClosed(context);
      }
    });
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
          automaticallyImplyLeading: false,
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
              onPressed: () {
                handleExit(context: context, roomRef: _roomRef, uid: widget.uid);              
              },
            ),
          ],
        ),
        
        body: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  
                  // SE IL RUOLO NON È ANCORA RIVELATO
                  if (!_isRoleRevealed) ...[
                    const Spacer(),
                    
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 80,
                      color: colorScheme.onPrimary,
                    ),
                    
                    const SizedBox(height: 10),
                    
                    Text(
                      'TOP SECRET',
                      style: textTheme.titleLarge!.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimary,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const Spacer(flex: 1),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.onPrimary)
                      ),
                      child: Text(
                        'This role is assigned only to you.\n\nMake sure no one else is looking at your screen before proceeding.',
                        style: textTheme.bodyMedium!.copyWith(
                          fontSize: 19,
                          color: colorScheme.onSecondary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const Spacer(flex: 2),

                    SizedBox(
                      width: 200,
                      height: 58,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.secondary,
                          foregroundColor: colorScheme.onSecondary,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _isRoleRevealed = true;
                          });
                        },
                        child: Text(
                          'SHOW ROLE',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSecondary,
                          ),
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                  ] 
                  
                  // SE IL RUOLO È STATO RIVELATO (Tua UI originale)
                  else ...[
                    Text(
                      'You are...',
                      style: textTheme.titleLarge!.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    Flexible(
                      flex: 12,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 5,
                              child: Text(
                                widget.roleName.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 57, 
                                  fontWeight: FontWeight.w900, 
                                  foreground: Paint()..color = widget.roleColor, 
                                  letterSpacing: 1
                                ),
                              ),
                            ),
                            Text(
                              widget.roleName.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 56, 
                                fontWeight: FontWeight.w900, 
                                foreground: Paint()..color = colorScheme.onPrimary,
                                letterSpacing: 2
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    Flexible(
                      flex: 30, 
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.secondary,
                            border: Border.all(
                              color: widget.roleColor, 
                              width: 8,
                            ),
                          ),
                          child: Center(
                            child: Image.asset(
                              widget.roleImage,
                              width: 220, 
                              height: 220,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.roleDescription,
                        style: textTheme.bodyMedium!.copyWith(
                          fontSize: 22,
                          color: colorScheme.onSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const Spacer(flex: 10), 

                    SizedBox(
                      width: 200,
                      height: 58,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.secondary,
                          foregroundColor: colorScheme.onSecondary,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NightTimeScreen(
                                roomId: widget.roomId,
                                uid: widget.uid,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSecondary,
                          ),
                        ),
                      ),
                    ),
                    
                    const Spacer(flex: 3),
                  ],
                ],
              ),
            ),
          ),
        ),
      )
    );
  }
}