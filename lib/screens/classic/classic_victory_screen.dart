import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../functions/functions.dart';

class ClassicVictoryScreen extends StatelessWidget {
  final String roomId;
  final String uid;
  final String winnerRole; // 'farmers' or 'werewolves'

  const ClassicVictoryScreen({
    super.key,
    required this.roomId,
    required this.uid,
    required this.winnerRole,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFarmers = winnerRole == 'farmers';
    final DatabaseReference roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/$roomId");

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isFarmers ? colorScheme.secondary : colorScheme.primary,
        body: StreamBuilder(
          stream: roomRef.onValue,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.snapshot.value == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) onRoomClosed(context);
              });
              return const Center(child: CircularProgressIndicator());
            }

            final data = (snapshot.hasData && snapshot.data?.snapshot.value != null)
                ? snapshot.data!.snapshot.value as Map
                : {};
            final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
            final myRole = playersMap[uid]?['role'] ?? 'Farmer';
            final bool isNarrator = myRole == 'Narrator';

            final Color primaryColor = isFarmers ? colorScheme.secondary : colorScheme.primary;
            final Color contrastColor = isFarmers ? colorScheme.primary : colorScheme.secondary;
            final Color textColor = isFarmers ? colorScheme.onSecondary : colorScheme.onPrimary;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const Spacer(flex: 1),

                    Text(
                      isFarmers ? 'VICTORY' : 'WEREWOLVES WIN!',
                      style: textTheme.titleLarge!.copyWith(
                        fontSize: isFarmers ? 50 : 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (isFarmers)
                      Text(
                        'FOR THE FARMERS!',
                        style: textTheme.titleLarge!.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),

                    const Spacer(flex: 2),

                    // Immagine vittoria
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: contrastColor.withOpacity(0.2),
                        border: Border.all(
                          color: isFarmers ? const Color(0xFF5A8920) : const Color(0xFF8B0000),
                          width: 6,
                        ),
                      ),
                      child: Center(
                        child: Image.asset(
                          isFarmers ? 'assets/images/farmer.png' : 'assets/images/logo.png',
                          width: 130,
                          height: 130,
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Box Narratore / Take attention
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: contrastColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isNarrator) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "now explain your villagers what happend",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isFarmers
                                  ? "The last wolf has been eliminated! Announce the triumphant victory to the villagers and reveal all secret roles."
                                  : "The werewolves have overrun the town! Announce their sinister victory and reveal who the werewolves were.",
                              style: TextStyle(
                                fontSize: 15,
                                color: isFarmers ? colorScheme.onPrimary : colorScheme.onSecondary,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ] else ...[
                            Icon(
                              Icons.record_voice_over,
                              size: 40,
                              color: isFarmers ? colorScheme.onPrimary : colorScheme.onSecondary,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Take attention to the narrator",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isFarmers ? colorScheme.onPrimary : colorScheme.onSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isFarmers
                                  ? "The village is saved! Listen as the narrator concludes the tale."
                                  : "The wolves have claimed the village! Listen as the narrator concludes the tale.",
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: (isFarmers ? colorScheme.onPrimary : colorScheme.onSecondary)
                                    .withOpacity(0.8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const Spacer(flex: 3),

                    SizedBox(
                      width: 200,
                      height: 58,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: contrastColor,
                          foregroundColor: isFarmers ? colorScheme.onPrimary : colorScheme.onSecondary,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          handleExit(context: context, roomRef: roomRef, uid: uid);
                        },
                        child: const Text(
                          'Exit Game',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
