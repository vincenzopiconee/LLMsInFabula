import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../functions/functions.dart';
import '../discussion_time_page.dart';
import '../dead_role_screen.dart';
import '../spectator_game_screen_day.dart';
import 'classic_narrator_day_page.dart';
import 'classic_victory_screen.dart';

class ClassicRecapNightPage extends StatefulWidget {
  final String roomId;
  final String uid;

  const ClassicRecapNightPage({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<ClassicRecapNightPage> createState() => _ClassicRecapNightPageState();
}

class _ClassicRecapNightPageState extends State<ClassicRecapNightPage> {
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

  Future<void> _checkWinConditionsAndProceed() async {
    final snapshot = await _roomRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.value as Map;
    final playersRaw = data['players'];
    final Map<dynamic, dynamic> playersMap = (playersRaw is Map) ? playersRaw : {};

    int wolvesCount = 0;
    int goodGuysCount = 0;

    playersMap.forEach((key, value) {
      if (value is Map) {
        final player = value;
        final bool isAlive = player['alive'] == true;
        final String role = player['role'] ?? '';

        if (isAlive && role != 'Spectator' && role != 'Narrator') {
          if (role == 'Werewolf') {
            wolvesCount++;
          } else {
            goodGuysCount++;
          }
        }
      }
    });

    if (wolvesCount == 0) {
      await _roomRef.update({'state': 'victory_farmers'});
    } else if (wolvesCount >= goodGuysCount) {
      await _roomRef.update({'state': 'victory_werewolves'});
    } else {
      final settings = data['settings'] != null ? Map<String, dynamic>.from(data['settings']) : {};
      final timeRules = settings['timeRules'] != null ? Map<String, dynamic>.from(settings['timeRules']) : {};
      final String discussionTimeStr = timeRules['discussion'] ?? "5m";
      final int durationSeconds = parseDuration(discussionTimeStr);

      await _roomRef.update({
        'state': 'discussion',
        'timer': {
          'startTime': ServerValue.timestamp,
          'duration': durationSeconds,
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.secondary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.close, color: colorScheme.onSecondary, size: 28),
              onPressed: () {
                handleExit(context: context, roomRef: _roomRef, uid: widget.uid);
              },
            ),
          ],
        ),
        body: StreamBuilder(
          stream: _roomRef.onValue,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.snapshot.value == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) onRoomClosed(context);
              });
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.snapshot.value as Map;
            final adminId = data['adminId'];
            final String currentState = data['state'] ?? '';
            final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
            final bool isHost = (adminId == widget.uid);

            final myData = playersMap[widget.uid] as Map?;
            final String myRole = myData?['role'] ?? 'Farmer';
            final bool isNarrator = (myRole == 'Narrator');

            final String nightResult = data['night_result']?.toString() ?? 'nobody';
            final Map? nightActions = data['night_actions'] as Map?;

            // Navigation
            if (!_hasNavigated) {
              if (currentState == 'discussion') {
                _hasNavigated = true;
                final bool amIAlive = myData?['alive'] ?? true;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (isNarrator) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClassicNarratorDayPage(roomId: widget.roomId, uid: widget.uid),
                      ),
                    );
                  } else if (myRole == 'Spectator') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SpectatorFormScreenDay(roomId: widget.roomId, uid: widget.uid),
                      ),
                    );
                  } else if (amIAlive) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DiscussionTimePage(roomId: widget.roomId, uid: widget.uid),
                      ),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeadRoleRevealScreen(roomId: widget.roomId, uid: widget.uid),
                      ),
                    );
                  }
                });
              } else if (currentState == 'victory_farmers') {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassicVictoryScreen(
                        roomId: widget.roomId,
                        uid: widget.uid,
                        winnerRole: 'farmers',
                      ),
                    ),
                  );
                });
              } else if (currentState == 'victory_werewolves') {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassicVictoryScreen(
                        roomId: widget.roomId,
                        uid: widget.uid,
                        winnerRole: 'werewolves',
                      ),
                    ),
                  );
                });
              }
            }

            final screenWidth = MediaQuery.of(context).size.width;
            final horizontalPadding =
                screenWidth > 900 ? 64.0 : (screenWidth > 600 ? 40.0 : 24.0);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int imageFlex;
                    int boxFlex;

                    if (constraints.maxWidth >= 1400 && constraints.maxHeight >= 700) {
                      imageFlex = 45;
                      boxFlex = 55;
                    } else if (constraints.maxWidth >= 1000 && constraints.maxHeight >= 620) {
                      imageFlex = 40;
                      boxFlex = 60;
                    } else if (constraints.maxWidth >= 750 && constraints.maxHeight >= 560) {
                      imageFlex = 36;
                      boxFlex = 64;
                    } else {
                      imageFlex = 30;
                      boxFlex = 70;
                    }

                    return Column(
                      children: [
                        Text(
                          'Tonight...',
                          style: textTheme.titleLarge!.copyWith(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        Flexible(
                          flex: imageFlex,
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: colorScheme.secondary, width: 3),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: const Image(
                                    image: AssetImage('assets/images/tonight.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Story Box / Narrator Notice Box
                        Expanded(
                          flex: boxFlex,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(18),
                              border: isNarrator
                                  ? Border.all(color: const Color(0xFFD4AF37), width: 2.5)
                                  : null,
                            ),
                            padding: const EdgeInsets.all(18),
                            child: isNarrator
                                ? _buildNarratorExplanationView(
                                    context, nightResult, nightActions, playersMap)
                                : _buildVillagerTakeAttention(context),
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (isHost)
                          SizedBox(
                            width: 200,
                            height: 58,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _checkWinConditionsAndProceed,
                              child: Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              isNarrator
                                  ? "When you finish explaining, tell the host to press Continue."
                                  : "Waiting for the host to continue...",
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSecondary,
                                fontStyle: FontStyle.italic,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVillagerTakeAttention(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.record_voice_over,
            size: 54,
            color: colorScheme.onPrimary.withOpacity(0.9),
          ),
          const SizedBox(height: 16),
          Text(
            "Take attention to the narrator",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            "The narrator will now explain what happened during the night.",
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: colorScheme.onPrimary.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNarratorExplanationView(
    BuildContext context,
    String nightResult,
    Map? nightActions,
    Map<String, dynamic> playersMap,
  ) {
    // Determine details
    String wolfTargetName = "None";
    if (nightActions != null && nightActions['werewolves'] != null) {
      final wolvesMap = Map<String, dynamic>.from(nightActions['werewolves']);
      if (wolvesMap.isNotEmpty) {
        final targetCounts = <String, int>{};
        wolvesMap.forEach((_, tid) => targetCounts[tid] = (targetCounts[tid] ?? 0) + 1);
        String? topTid;
        int topV = 0;
        targetCounts.forEach((tid, count) {
          if (count > topV) {
            topV = count;
            topTid = tid;
          }
        });
        if (topTid != null) {
          wolfTargetName = playersMap[topTid]?['name'] ?? "Unknown";
        }
      }
    }

    String doctorTargetName = "None";
    if (nightActions != null && nightActions['doctor'] != null) {
      final docMap = Map<String, dynamic>.from(nightActions['doctor']);
      if (docMap.isNotEmpty) {
        final docTid = docMap.values.first;
        doctorTargetName = playersMap[docTid]?['name'] ?? "Unknown";
      }
    }

    String outcomeText;
    Color outcomeColor;
    if (nightResult == 'saved') {
      outcomeText = "Attack was BLOCKED! The Doctor saved $wolfTargetName.";
      outcomeColor = Colors.greenAccent;
    } else if (nightResult != 'nobody') {
      final deadName = playersMap[nightResult]?['name'] ?? "A villager";
      outcomeText = "KILL SUCCESSFUL! $deadName was killed by werewolves.";
      outcomeColor = Colors.redAccent;
    } else {
      outcomeText = "Peaceful night. No one was killed.";
      outcomeColor = Colors.lightBlueAccent;
    }

    String seerNote = "";
    if (nightActions != null && nightActions['seer'] != null) {
      final seerData = nightActions['seer'];
      String? stid;
      if (seerData is Map) {
        stid = seerData['target']?.toString() ??
            (seerData.isNotEmpty ? seerData.values.first?.toString() : null);
      }
      if (stid != null) {
        final sname = playersMap[stid]?['name'] ?? "Unknown";
        final srole = playersMap[stid]?['role'] ?? "Unknown";
        seerNote = "🔮 Seer inspected: $sname ($srole)";
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner obbligatorio richiesto dall'utente
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: const [
                Icon(Icons.campaign, color: Colors.black, size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "now explain your villagers what happend",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Text(
            "Night Actions Summary:",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),

          _buildDetailRow("🐺 Werewolves targeted:", wolfTargetName),
          const SizedBox(height: 4),
          _buildDetailRow("🩺 Doctor protected:", doctorTargetName),
          const SizedBox(height: 6),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: outcomeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: outcomeColor.withOpacity(0.6)),
            ),
            child: Text(
              "⚔️ Result: $outcomeText",
              style: TextStyle(
                color: outcomeColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

          if (seerNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              seerNote,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],

          const SizedBox(height: 10),
          const Text(
            "Tell the villagers what happened in your own storytelling words without revealing secret roles. When finished, inform the host to press Continue.",
            style: TextStyle(
              color: Colors.white70,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
