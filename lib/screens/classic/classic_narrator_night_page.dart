import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../functions/functions.dart';
import '../../functions/night_timer.dart';
import '../daytime_page.dart';

class ClassicNarratorNightPage extends StatefulWidget {
  final String roomId;
  final String uid;

  const ClassicNarratorNightPage({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<ClassicNarratorNightPage> createState() => _ClassicNarratorNightPageState();
}

class _ClassicNarratorNightPageState extends State<ClassicNarratorNightPage> {
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
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              "Narrator Dashboard",
              style: TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.close, color: colorScheme.onPrimary, size: 28),
              onPressed: () {
                handleExit(context: context, roomRef: _roomRef, uid: widget.uid);
              },
            ),
          ],
        ),
        body: StreamBuilder(
          stream: _roomRef.onValue,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
            }

            if (snapshot.hasData && snapshot.data!.snapshot.value == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) onRoomClosed(context);
              });
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final data = snapshot.data!.snapshot.value as Map;
            final String currentState = data['state'] ?? '';
            final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
            final nightActions = data['night_actions'] as Map?;

            // Navigazione Automatica verso il Giorno
            if (currentState == 'day_phase' && !_hasNavigated) {
              _hasNavigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DayTimeScreen(roomId: widget.roomId, uid: widget.uid),
                  ),
                );
              });
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Timer Barra Notturna
                    NightTimerWidget(
                      roomId: widget.roomId,
                      uid: widget.uid,
                      fixedRole: 'Narrator',
                      onTimerEnd: () {},
                    ),

                    const SizedBox(height: 12),

                    // Titolo
                    Row(
                      children: [
                        const Icon(Icons.nightlight_round, color: Color(0xFFD4AF37), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          "Night Actions in Progress",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Azioni in tempo reale
                    _buildLiveActionsCard(context, nightActions, playersMap),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Icon(Icons.people_alt, color: Color(0xFFD4AF37), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          "Players & Secret Roles",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Lista dei giocatori e stato
                    Expanded(
                      child: _buildPlayersList(context, playersMap),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLiveActionsCard(
    BuildContext context,
    Map? nightActions,
    Map<String, dynamic> playersMap,
  ) {
    // 1. Werewolf target
    String werewolfTargetText = "Waiting for wolves...";
    if (nightActions != null && nightActions['werewolves'] != null) {
      final wolvesMap = Map<String, dynamic>.from(nightActions['werewolves']);
      if (wolvesMap.isNotEmpty) {
        final targetCounts = <String, int>{};
        wolvesMap.forEach((_, targetId) {
          targetCounts[targetId] = (targetCounts[targetId] ?? 0) + 1;
        });
        String? leadTarget;
        int maxVotes = 0;
        targetCounts.forEach((targetId, count) {
          if (count > maxVotes) {
            maxVotes = count;
            leadTarget = targetId;
          }
        });
        if (leadTarget != null) {
          final targetName = playersMap[leadTarget]?['name'] ?? "Unknown";
          werewolfTargetText = "Targeting: $targetName ($maxVotes votes)";
        }
      }
    }

    // 2. Doctor target
    String doctorTargetText = "Waiting for Doctor...";
    if (nightActions != null && nightActions['doctor'] != null) {
      final docMap = Map<String, dynamic>.from(nightActions['doctor']);
      if (docMap.isNotEmpty) {
        final targetId = docMap.values.first;
        final targetName = playersMap[targetId]?['name'] ?? "Unknown";
        doctorTargetText = "Protecting: $targetName";
      }
    }

    // 3. Seer target
    String seerTargetText = "Waiting for Seer...";
    if (nightActions != null && nightActions['seer'] != null) {
      final seerData = nightActions['seer'];
      String? targetId;
      if (seerData is Map) {
        if (seerData.containsKey('target')) {
          targetId = seerData['target']?.toString();
        } else if (seerData.isNotEmpty) {
          targetId = seerData.values.first?.toString();
        }
      }
      if (targetId != null) {
        final targetName = playersMap[targetId]?['name'] ?? "Unknown";
        final targetRole = playersMap[targetId]?['role'] ?? "Unknown";
        seerTargetText = "Inspecting: $targetName ($targetRole)";
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionRow(
            icon: Icons.pets,
            color: const Color(0xFF8B0000),
            title: "Werewolves",
            detail: werewolfTargetText,
          ),
          const Divider(color: Colors.white24, height: 16),
          _buildActionRow(
            icon: Icons.healing,
            color: const Color(0xFF5A8920),
            title: "Doctor",
            detail: doctorTargetText,
          ),
          const Divider(color: Colors.white24, height: 16),
          _buildActionRow(
            icon: Icons.remove_red_eye,
            color: const Color(0xFF166AF1),
            title: "Seer",
            detail: seerTargetText,
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required Color color,
    required String title,
    required String detail,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          "$title:",
          style: const TextStyle(
            color:  Color(0xFF022F40),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            detail,
            style: const TextStyle(
              color:  Color(0xFF022F40),
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayersList(BuildContext context, Map<String, dynamic> playersMap) {
    final List<Map<String, dynamic>> players = [];
    playersMap.forEach((key, value) {
      if (value is Map) {
        players.add({
          "uid": key,
          "name": value['name'] ?? "Unknown",
          "role": value['role'] ?? "Farmer",
          "alive": value['alive'] == true,
          "phaseStatus": value['phaseStatus'],
        });
      }
    });

    // Exclude the narrator themselves and spectators
    final activePlayers = players.where((p) => p['role'] != 'Narrator' && p['role'] != 'Spectator').toList();

    return ListView.separated(
      itemCount: activePlayers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = activePlayers[index];
        final bool isAlive = p['alive'] == true;
        final bool isSleeping = p['phaseStatus'] == 'sleeping';
        final String role = p['role'] ?? 'Farmer';

        Color roleColor;
        switch (role) {
          case 'Werewolf':
            roleColor = const Color(0xFF8B0000);
            break;
          case 'Doctor':
            roleColor = const Color(0xFF5A8920);
            break;
          case 'Seer':
            roleColor = const Color(0xFF166AF1);
            break;
          case 'Medium':
            roleColor = const Color(0xFF9A5EA8);
            break;
          case 'Farmer':
          default:
            roleColor = const Color.fromARGB(255, 141, 134, 29);
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAlive ? roleColor : Colors.grey,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isAlive ? roleColor : Colors.grey,
                child: Text(
                  p['name'].isNotEmpty ? p['name'][0].toUpperCase() : "?",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        decoration: isAlive ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    Text(
                      role,
                      style: TextStyle(
                        fontSize: 13,
                        color: isAlive ? roleColor : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: !isAlive
                      ? Colors.black54
                      : (isSleeping ? Colors.green.withValues(alpha:0.4) : Colors.orange.withValues(alpha:0.4)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  !isAlive
                      ? "Dead"
                      : (isSleeping ? "Sleeping 💤" : "Awake 👁️"),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: !isAlive
                        ? Colors.grey
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
