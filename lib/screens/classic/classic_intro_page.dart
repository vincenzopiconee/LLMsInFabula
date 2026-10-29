import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../../functions/functions.dart';
import '../../services/role_data.dart';
import '../role_reveal_screen.dart';

class ClassicIntroPage extends StatefulWidget {
  final String roomId;
  final String uid;

  const ClassicIntroPage({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<ClassicIntroPage> createState() => _ClassicIntroPageState();
}

class _ClassicIntroPageState extends State<ClassicIntroPage> {
  late DatabaseReference _roomRef;
  bool _hasNavigatedToRole = false;

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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.primary,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.close, color: colorScheme.secondary),
              onPressed: () {
                handleExit(context: context, roomRef: _roomRef, uid: widget.uid);
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: StreamBuilder(
          stream: _roomRef.onValue,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            if (snapshot.hasData && snapshot.data!.snapshot.value == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  onRoomClosed(context);
                }
              });
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final data = snapshot.data!.snapshot.value as Map;
            final String? state = data['state'];
            final String? adminId = data['adminId'];
            final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
            final myData = playersMap[widget.uid] as Map?;
            final String myRole = myData?['role'] ?? 'Farmer';
            final bool isNarrator = myRole == 'Narrator';
            final bool amIAdmin = widget.uid == adminId;

            if (state == 'reveal_roles' && !_hasNavigatedToRole) {
              _hasNavigatedToRole = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final roleData = rolesData[myRole] ?? rolesData['Farmer']!;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => RoleRevealScreen(
                      roleName: roleData.name,
                      roleImage: roleData.image,
                      roleDescription: roleData.description,
                      roleColor: roleData.color,
                      roomId: widget.roomId,
                      uid: widget.uid,
                    ),
                  ),
                );
              });
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
                      imageFlex = 65;
                      boxFlex = 35;
                    } else if (constraints.maxWidth >= 1000 && constraints.maxHeight >= 620) {
                      imageFlex = 56;
                      boxFlex = 44;
                    } else if (constraints.maxWidth >= 750 && constraints.maxHeight >= 560) {
                      imageFlex = 48;
                      boxFlex = 52;
                    } else {
                      imageFlex = 40;
                      boxFlex = 60;
                    }

                    final spacerTopFlex = constraints.maxHeight >= 600 ? 3 : 2;
                    final spacerBottomFlex = constraints.maxHeight >= 600 ? 2 : 1;

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            'Once upon a time...',
                            style: textTheme.titleLarge!.copyWith(
                              fontSize: 38,
                              color: colorScheme.onPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
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
                                  borderRadius: BorderRadius.circular(15),
                                  child: const Image(
                                    image: AssetImage('assets/images/screen_intro.jpg'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Testo centrale / Area Narratore
                        Expanded(
                          flex: boxFlex,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: colorScheme.secondary,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colorScheme.secondary, width: 3),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: isNarrator
                                ? _buildNarratorGuide(context)
                                : _buildPlayerTakeAttention(context),
                          ),
                        ),

                        Spacer(flex: spacerTopFlex),

                        if (amIAdmin)
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
                              onPressed: () async {
                                await _roomRef.update({'state': 'reveal_roles'});
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
                          )
                        else
                          Text(
                            "Waiting for the host to continue...",
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimary,
                              fontStyle: FontStyle.italic,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),

                        Spacer(flex: spacerBottomFlex),
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

  Widget _buildPlayerTakeAttention(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.record_voice_over,
            size: 54,
            color: colorScheme.onSecondary.withOpacity(0.9),
          ),
          const SizedBox(height: 16),
          Text(
            "Take attention to the narrator",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSecondary,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "The story is being told live by the narrator.",
            style: TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: colorScheme.onSecondary.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNarratorGuide(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFD4AF37),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: Colors.black, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                "You are the Narrator",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Introduce the village to the players and set the scene:\n"
            "• Welcome the villagers to the town.\n"
            "• Describe the peaceful evening and explain that mysterious werewolves have quietly infiltrated the village.\n"
            "• Tell the players that their roles will now be secretly revealed.\n\n"
            "When you have finished introducing the story, tell the host to press Continue.",
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
