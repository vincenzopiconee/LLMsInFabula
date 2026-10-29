import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../functions/functions.dart';
import '../../functions/discussion_timer.dart';
import '../../functions/voting_timer.dart';
import 'classic_voting_result_page.dart';

class ClassicNarratorDayPage extends StatefulWidget {
  final String roomId;
  final String uid;

  const ClassicNarratorDayPage({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<ClassicNarratorDayPage> createState() => _ClassicNarratorDayPageState();
}

class _ClassicNarratorDayPageState extends State<ClassicNarratorDayPage> {
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
        backgroundColor: colorScheme.secondary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 150,
          leading: RoleGuideDrawerButton(
            color: colorScheme.onSecondary,
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
            final String currentState = data['state'] ?? '';
            final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
            final dayVotes = Map<String, dynamic>.from(data['day_votes'] ?? {});

            if (currentState == 'voting_results' && !_hasNavigated) {
              _hasNavigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClassicVotingResultPage(roomId: widget.roomId, uid: widget.uid),
                  ),
                );
              });
            }

            final bool isVoting = (currentState == 'voting');
            final screenWidth = MediaQuery.of(context).size.width;
            final horizontalPadding = screenWidth > 900 ? 64.0 : (screenWidth > 600 ? 40.0 : 20.0);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int imageFlex;
                    int listFlex;
                    if (constraints.maxWidth >= 1400 && constraints.maxHeight >= 700) {
                      imageFlex = 45;
                      listFlex = 55;
                    } else if (constraints.maxWidth >= 1000 && constraints.maxHeight >= 620) {
                      imageFlex = 40;
                      listFlex = 60;
                    } else if (constraints.maxWidth >= 750 && constraints.maxHeight >= 560) {
                      imageFlex = 34;
                      listFlex = 66;
                    } else {
                      imageFlex = 28;
                      listFlex = 72;
                    }

                    return Column(
                      children: [
                        const SizedBox(height: 8),

                        // Timer Barra
                        if (!isVoting)
                          DiscussionTimerWidget(
                            roomId: widget.roomId,
                            uid: widget.uid,
                            onTimerEnd: () {},
                          )
                        else
                          VotingTimerWidget(
                            roomId: widget.roomId,
                            uid: widget.uid,
                            onTimerEnd: () {},
                          ),

                        const SizedBox(height: 12),

                        // Immagine Discussione
                        if (!isVoting) ...[
                          Flexible(
                            flex: imageFlex,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colorScheme.onSecondary,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(13),
                                    child: const Image(
                                      image: AssetImage('assets/images/discussion.png'),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Info banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isVoting ? Icons.how_to_vote : Icons.forum,
                                color: const Color(0xFFD4AF37),
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isVoting
                                      ? "Voting Phase: Live votes are appearing below"
                                      : "Discussion Phase: Moderating village debate",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            const Icon(Icons.people_alt, color: Color(0xFFD4AF37), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isVoting ? "Live Votes & Status" : "Villagers & Roles",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSecondary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Lista Giocatori
                        Expanded(
                          flex: (!isVoting) ? listFlex : 100,
                          child: _buildPlayersList(context, playersMap, dayVotes, isVoting),
                        ),
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

  Widget _buildPlayersList(
    BuildContext context,
    Map<String, dynamic> playersMap,
    Map<String, dynamic> dayVotes,
    bool isVoting,
  ) {
    final List<Map<String, dynamic>> players = [];
    playersMap.forEach((key, value) {
      if (value is Map) {
        players.add({
          "uid": key,
          "name": value['name'] ?? "Unknown",
          "role": value['role'] ?? "Farmer",
          "alive": value['alive'] == true,
          "isReadyForVoting": value['isReadyForVoting'] == true,
        });
      }
    });

    final activePlayers =
        players.where((p) => p['role'] != 'Narrator' && p['role'] != 'Spectator').toList();

    // Calculate votes received per player
    final Map<String, int> votesReceived = {};
    dayVotes.forEach((_, targetId) {
      if (targetId != 'skip') {
        votesReceived[targetId] = (votesReceived[targetId] ?? 0) + 1;
      }
    });

    return ListView.separated(
      itemCount: activePlayers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = activePlayers[index];
        final String uid = p['uid'];
        final bool isAlive = p['alive'] == true;
        final String role = p['role'] ?? 'Farmer';
        final int votes = votesReceived[uid] ?? 0;
        final bool hasVoted = dayVotes.containsKey(uid);
        final bool isReady = p['isReadyForVoting'] == true;

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
            color: Theme.of(context).colorScheme.primary,
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
                        color: isAlive ? Colors.white : Colors.grey,
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

              if (isVoting && isAlive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: votes > 0 ? Colors.redAccent.withOpacity(0.3) : Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: votes > 0 ? Colors.redAccent : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    votes > 0 ? "$votes votes" : (hasVoted ? "Voted" : "Thinking..."),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: votes > 0
                          ? Colors.redAccent
                          : (hasVoted ? Colors.greenAccent : Colors.white70),
                    ),
                  ),
                )
              else if (!isVoting && isAlive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isReady ? Colors.green.withOpacity(0.2) : Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isReady ? "Ready to Vote" : "Discussing",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isReady ? Colors.greenAccent : Colors.white,
                    ),
                  ),
                )
              else if (!isAlive)
                const Text(
                  "Dead 💀",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        );
      },
    );
  }
}
