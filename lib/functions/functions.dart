import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/tts_manager.dart';

// Spostiamo qui la costante così è accessibile a tutte le pagine
const String kDatabaseUrl = 'https://llminfabula-1-default-rtdb.europe-west1.firebasedatabase.app';

bool _isVoluntaryExit = false;
bool _isRoomClosedHandling = false;

/// Resets exit state for a fresh game/lobby.
void resetExitFlags() {
  _isVoluntaryExit = false;
  _isRoomClosedHandling = false;
}

/// Marks that the local user chose to exit/close the room.
void markVoluntaryExit() {
  _isVoluntaryExit = true;
  _isRoomClosedHandling = true;
  Future.delayed(const Duration(seconds: 4), () {
    _isVoluntaryExit = false;
    _isRoomClosedHandling = false;
  });
}

/// Safely handles room closed notification without looping or double-notifying.
void onRoomClosed(BuildContext context) {
  // If the user exited voluntarily, do not show "The lobby has been closed by the host."
  if (_isVoluntaryExit || _isRoomClosedHandling) return;
  _isRoomClosedHandling = true;

  Future.delayed(const Duration(seconds: 4), () {
    _isRoomClosedHandling = false;
    _isVoluntaryExit = false;
  });

  if (!context.mounted) return;

  ttsManager.stop();
  Navigator.of(context).popUntil((route) => route.isFirst);

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("The lobby has been closed by the host."),
      backgroundColor: Colors.red,
      duration: Duration(seconds: 2),
    ),
  );
}

/// Gestisce l'uscita dalla partita (sia per Admin che per User)
Future<void> handleExit({
  required BuildContext context,
  required DatabaseReference roomRef,
  required String uid,
}) async {
  // 1. Recuperiamo lo stato attuale per sapere se siamo Admin
  final snapshot = await roomRef.get();
  
  // Se la stanza non esiste più, usciamo direttamente
  if (!snapshot.exists) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    return;
  }

  final data = snapshot.value as Map;
  final adminId = data['adminId'];
  final bool amIAdmin = (uid == adminId);

  if (!context.mounted) return;

  // 2. Dialog di conferma
  final shouldExit = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(amIAdmin ? "Close the room?" : "Leave the game?"),
      content: Text(amIAdmin 
        ? "You're the host. If you leave, the room will be deleted and all players will be disconnected."
        : "Are you sure you want to leave the game?"
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(amIAdmin ? "Close Room" : "Leave Game"),
        ),
      ],
    ),
  );

  if (shouldExit != true) return;

  markVoluntaryExit();
  ttsManager.stop();

  // 3. Esecuzione logica DB
  if (amIAdmin) {
    // Se sei Admin, cancella tutta la stanza (Nuke)
    await roomRef.remove();
  } else {
    // Se sei User, rimuovi solo te stesso dalla lista giocatori
    await roomRef.child("players/$uid").remove();
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).clearSnackBars();
    // Torna alla schermata iniziale rimuovendo le schermate intermedie
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}


class RoleRulesDrawer extends StatelessWidget {
  const RoleRulesDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Mappa ruoli → descrizioni
    final Map<String, String> roleDescriptions = {
      'Werewolf': 'Choose a victim at night. Win if the wolves eliminate all the villagers.',
      'Farmer': 'Simple villager with no special powers. Win by discovering and voting out the wolves.',
      'Doctor': 'Each night, choose a player to protect: if they are attacked, they survive.',
      'Seer': 'Each night, you can discover whether a player is a wolf or not.',
      'Medium': 'You can gain additional information about players who died during the game.',
      'Spectator': 'Observe the game without influencing it, you see the events but you can not vote.',
      'Dead': 'You are out of the game, but you can continue to follow the match.',
    };

     return Drawer(
      backgroundColor: colorScheme.primary,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Role Rules',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.secondary,
                ),
              ),
            ),
            const Divider(color: Colors.grey),

            // Werewolf
            _buildRoleExpansionTile(
              context: context,
              iconWidget: SizedBox(
                width: 36,
                height: 36,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft, // tutte ancorate allo stesso punto
                  child: SvgPicture.asset(
                    'assets/images/werewolf_white.svg',
                    colorFilter: ColorFilter.mode(
                      colorScheme.secondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              title: 'Werewolf',
              color: colorScheme.secondary,
              description: roleDescriptions['Werewolf']!,
            ),

            _buildRoleExpansionTile(
              context: context,
              iconWidget: SizedBox(
                width: 36,
                height: 36,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  child: SvgPicture.asset(
                    'assets/images/farmer_white.svg',
                    colorFilter: ColorFilter.mode(
                      colorScheme.secondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),

              title: 'Farmer',
              color: colorScheme.secondary,
              description: roleDescriptions['Farmer']!,
            ),

            _buildRoleExpansionTile(
              context: context,
              iconWidget: SizedBox(
                width: 36,
                height: 36,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  child: SvgPicture.asset(
                    'assets/images/doctor_white.svg',
                    colorFilter: ColorFilter.mode(
                      colorScheme.secondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),

              title: 'Doctor',
              color: colorScheme.secondary,
              description: roleDescriptions['Doctor']!,
            ),

            _buildRoleExpansionTile(
              context: context,
              iconWidget: SizedBox(
                width: 36,
                height: 36,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  child: SvgPicture.asset(
                    'assets/images/seer_white.svg',
                    colorFilter: ColorFilter.mode(
                      colorScheme.secondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),

              title: 'Seer',
              color: colorScheme.secondary,
              description: roleDescriptions['Seer']!,
            ),

            _buildRoleExpansionTile(
              context: context,
              iconWidget: SizedBox(
                width: 36,
                height: 36,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  child: SvgPicture.asset(
                    'assets/images/medium_white.svg',
                    colorFilter: ColorFilter.mode(
                      colorScheme.secondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),

              title: 'Medium',
              color: colorScheme.secondary,
              description: roleDescriptions['Medium']!,
            ),

            _buildRoleExpansionTile(
              context: context,
              iconWidget: SizedBox(
                width: 36,
                height: 36,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  child: SvgPicture.asset(
                    'assets/images/spectator_white.svg',
                    colorFilter: ColorFilter.mode(
                      colorScheme.secondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),

              title: 'Spectator',
              color: colorScheme.secondary,
              description: roleDescriptions['Spectator']!,
            ),

            _buildRoleExpansionTile(
              context: context,
              iconWidget: SizedBox(
                width: 36,
                height: 36,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  child: SvgPicture.asset(
                    'assets/images/dead_white.svg',
                    colorFilter: ColorFilter.mode(
                      colorScheme.secondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),

              title: 'Dead',
              color: colorScheme.secondary,
              description: roleDescriptions['Dead']!,
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleExpansionTile({
    required BuildContext context,
    required Widget iconWidget,
    required String title,
    required Color color,
    required String description,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent, // niente riga interna
      ),
      child: ExpansionTile(
        leading: iconWidget,
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        iconColor: color,
        collapsedIconColor: color,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              description,
              style: textTheme.bodyMedium!.copyWith(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


int parseDuration(String timeStr) {
  if (timeStr.endsWith('m')) {
    return int.parse(timeStr.replaceAll('m', '')) * 60;
  }
  if (timeStr.endsWith('s')) {
    return int.parse(timeStr.replaceAll('s', ''));
  }
  return 60; // Default fallback
}



