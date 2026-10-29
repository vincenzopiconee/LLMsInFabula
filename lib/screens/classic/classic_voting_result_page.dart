import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../functions/functions.dart';
import '../nighttime_page.dart';
import 'classic_victory_screen.dart';

class ClassicVotingResultPage extends StatefulWidget {
  final String roomId;
  final String uid;

  const ClassicVotingResultPage({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<ClassicVotingResultPage> createState() => _ClassicVotingResultPageState();
}

class _ClassicVotingResultPageState extends State<ClassicVotingResultPage> {
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

  Future<void> _checkGameStatusAndProceed() async {
    final snapshot = await _roomRef.get();
    if (!snapshot.exists || snapshot.value == null) return;

    final roomData = snapshot.value as Map;
    final playersMap = Map<dynamic, dynamic>.from(roomData['players'] ?? {});

    int wolvesCount = 0;
    int goodGuysCount = 0;

    playersMap.forEach((key, value) {
      if (value is Map) {
        final bool isAlive = value['alive'] == true;
        final String role = value['role'] ?? '';

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
      final settings = roomData['settings'] != null ? Map<String, dynamic>.from(roomData['settings']) : {};
      final timeRules = settings['timeRules'] != null ? Map<String, dynamic>.from(settings['timeRules']) : {};
      final String nightDurationStr = timeRules['night'] ?? "2m";
      final int nightDurationSeconds = parseDuration(nightDurationStr);

      await _roomRef.update({
        "state": "night",
        "day_votes": null,
        "night_actions": null,
        "tied_players": null,
        "timer": {
          "startTime": ServerValue.timestamp,
          "duration": nightDurationSeconds,
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

            final String dayResult = data['day_result']?.toString() ?? 'nobody';

            // Navigation
            if (!_hasNavigated) {
              if (currentState == 'night') {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NightTimeScreen(roomId: widget.roomId, uid: widget.uid),
                    ),
                  );
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
                          'The village has spoken...',
                          style: textTheme.titleLarge!.copyWith(
                            fontSize: 34,
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
                                    image: AssetImage('assets/images/result.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

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
                                ? _buildNarratorVotingSummary(context, dayResult, playersMap)
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
                              onPressed: _checkGameStatusAndProceed,
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
            "The narrator will now explain the voting results to the village.",
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

  Widget _buildNarratorVotingSummary(
    BuildContext context,
    String dayResult,
    Map<String, dynamic> playersMap,
  ) {
    String outcomeTitle;
    String outcomeDescription;
    Color outcomeColor;

    if (dayResult == 'nobody') {
      outcomeTitle = "No One Executed";
      outcomeDescription = "The village vote ended in a tie or skip. No player was sent to the pyre today.";
      outcomeColor = Colors.orangeAccent;
    } else {
      final victimName = playersMap[dayResult]?['name'] ?? "A player";
      outcomeTitle = "$victimName was Executed";
      outcomeDescription = "The village condemned $victimName to the pyre. Remember: Do not reveal whether they were a Werewolf or a Farmer!";
      outcomeColor = Colors.redAccent;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: outcomeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: outcomeColor.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outcomeTitle,
                  style: TextStyle(
                    color: outcomeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  outcomeDescription,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            "Explain the dramatic outcome of the vote to the villagers. When ready, tell the host to press Continue to advance to the next night.",
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
}
