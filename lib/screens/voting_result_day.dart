import 'dart:async'; 
import '../services/ai_story_generator.dart'; 
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import 'package:llm_in_fabula/services/tts_manager.dart'; 

import 'nighttime_page.dart';
import 'werewolf_victory_screen.dart';
import 'farmer_victory_screen.dart';

class VotingResultDay extends StatefulWidget {
  final String roomId;
  final String uid;

  const VotingResultDay({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<VotingResultDay> createState() => _VotingResultDayState();
}

class _VotingResultDayState extends State<VotingResultDay> {
  late DatabaseReference _roomRef;
  bool _hasNavigated = false;
  bool _isGenerating = false;

  // --- STATI SINCRONIZZAZIONE ---
  bool _isAudioLoading = false; 
  String? _readyAudioFile;        
  bool _audioProcessed = false;        
  // RIMOSSO _isMuted locale
  // ---------------------------------------------

  // --- TYPEWRITER ---
  String _displayedText = "";
  Timer? _typewriterTimer;
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  // ------------------

   // Mappa dall'id salvato nel DB al path dell'immagine
  final Map<String, String> _narratorAssetMap = {
    'Bard storyteller': 'assets/images/bard.png',
    'Dark Wizard': 'assets/images/wizard.png',
    'Oracle': 'assets/images/oracle.png',
    'Old folk': 'assets/images/folk.png',
  };

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kDatabaseUrl,
    ).ref("rooms/${widget.roomId}");

    _checkAndGenerateRecap();
  }

  @override
  void dispose() {
    ttsManager.stop();
    _typewriterTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // --- LOGICA TYPEWRITER ---
  void _startTypewriter(String fullText) {
    if (_isTyping || _displayedText.isNotEmpty) return;

    _isTyping = true;
    _displayedText = "";
    int currentIndex = 0;

    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (currentIndex < fullText.length) {
        if (mounted) {
          setState(() {
            _displayedText += fullText[currentIndex];
            currentIndex++;
          });
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        }
      } else {
        _isTyping = false;
        timer.cancel();
      }
    });
  }

  // --- LOGICA MUTE GLOBALE ---
  void _toggleMute() {
    setState(() {
      ttsManager.toggleMute();
      if (!ttsManager.isMuted && _readyAudioFile != null) {
        ttsManager.playAudioPath(_readyAudioFile);
      }
    });
  }

  Future<void> _checkAndGenerateRecap() async {
    final snapshot = await _roomRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.value as Map;
    final adminId = data['adminId'];
    final Map? stories = data['generated_stories'] as Map?;

    if (stories != null && stories['current_story'] != null) return;
    
    if (adminId != widget.uid) return;

    setState(() => _isGenerating = true);

    final aiGen = AiStoryGenerator(_roomRef);
    await aiGen.generateStory('day_recap'); 

    if (mounted) setState(() => _isGenerating = false);
  }


  Future<void> _checkGameStatusAndProceed() async {
    await ttsManager.stop(); 

    final snapshot = await _roomRef.get();
    
    if (!snapshot.exists || snapshot.value == null) return;

    final roomData = snapshot.value;
    Map<dynamic, dynamic> playersMap = {};

    if (roomData is Map && roomData.containsKey('players')) {
      final playersRaw = roomData['players'];
      if (playersRaw is Map) {
        playersMap = playersRaw;
      }
    } else {
      return;
    }
    
    int wolvesCount = 0;
    int goodGuysCount = 0;

    playersMap.forEach((key, value) {
      if (value is Map) {
        final player = value; 
        final String role = player['role']?.toString().trim() ?? '';
        final rawAlive = player['alive'];
        final bool isAlive = (rawAlive == true || rawAlive.toString().toLowerCase() == 'true');

        if (isAlive && role != 'Spectator') {
          if (role.toLowerCase() == 'werewolf') {
            wolvesCount++;
          } else {
            goodGuysCount++;
          }
        }
      }
    });

    String nextState = "";

    if (wolvesCount == 0) {
      nextState = "victory_farmers";
      await AiStoryGenerator(_roomRef).generateStory('victory_farmers');
    } else if (wolvesCount >= goodGuysCount) {
      nextState = "victory_werewolves";
      await AiStoryGenerator(_roomRef).generateStory('victory_werewolves');
    } else {
      nextState = "night_phase";
      
      await _roomRef.update({
        "night_actions": null, 
        "day_votes": null,     
        "day_result": null,    
        "night_result": null,  
        "pyre_votes": null,    
        "tied_players": null,  
      });
    }

    await _roomRef.child('generated_stories/current_story').remove();
    await _roomRef.update({'state': nextState});
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
                if (context.mounted) {
                  onRoomClosed(context);
                }
              });
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.snapshot.value as Map;

            // --- NECESSITIES FOR DISPLAYING LLM TALKING ---
            final settings = data['settings'] as Map? ?? {};
            final String narratorStyle = settings['llmNarrator']?.toString() ?? "Narrator"; 
            final String? narratorAsset = _narratorAssetMap[narratorStyle];
            
            final Map? stories = data['generated_stories'] as Map?;
            final String? aiStoryText = stories?['current_story']; 
            final String? narratorError = stories?['narrator_error'];
            final bool hasNarratorError = narratorError != null || (aiStoryText?.startsWith('⚠️') ?? false);
            final bool isStoryReady = aiStoryText != null && aiStoryText.isNotEmpty && !hasNarratorError;
            // ------------------------------------------------

            final adminId = data['adminId'];
            final String currentState = data['state'] ?? '';
            final bool isHost = (adminId == widget.uid);

            // --- LOGICA SINCRONIZZAZIONE ---
            if (isStoryReady && !_isAudioLoading && !_audioProcessed) {
              _isAudioLoading = true;
              
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                String? audioFile = await ttsManager.generateAudioFile(aiStoryText, narratorStyle);
                
                if (context.mounted) {
                  setState(() {
                    _readyAudioFile = audioFile;
                    _isAudioLoading = false;
                    _audioProcessed = true;
                  });

                  // Usa singleton mute check
                  if (audioFile != null && !ttsManager.isMuted) {
                    ttsManager.playAudioPath(audioFile);
                  }
                  _startTypewriter(aiStoryText);
                }
              });
            }

            // --- GESTIONE STATI DI CARICAMENTO / ERRORE ---
            bool showLoading = false;
            String loadingMessage = "";

            if (hasNarratorError) {
              showLoading = false;
              if (_displayedText.isEmpty) {
                _displayedText = (aiStoryText != null && !aiStoryText.startsWith('⚠️'))
                    ? aiStoryText
                    : "The narrator was momentarily lost for words...\nYou may continue with the game.";
              }
            } else if (!isStoryReady) {
              showLoading = true;
              loadingMessage = _isGenerating ? "The narrator is judging..." : "Waiting for the verdict...";
            } else if (_isAudioLoading) {
              showLoading = true;
              loadingMessage = "The narrator is clearing their throat...";
            }

            // --- GESTIONE NAVIGAZIONE ---
            if (!_hasNavigated) {
              if (currentState == 'night_phase') {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => NightTimeScreen(roomId: widget.roomId, uid: widget.uid))
                  );
                });
              } else if (currentState == 'victory_werewolves') {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => WerewolvesWinScreen(roomId: widget.roomId, uid: widget.uid))
                  );
                });
              } else if (currentState == 'victory_farmers') {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => FarmersWinScreen(roomId: widget.roomId, uid: widget.uid))
                  );
                });
              }
            }

            final screenWidth = MediaQuery.of(context).size.width;
            final horizontalPadding = screenWidth > 900 ? 64.0 : (screenWidth > 600 ? 40.0 : 24.0);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int imageFlex;
                    int boxFlex;

                    if (constraints.maxWidth >= 1400 && constraints.maxHeight >= 700) {
                      imageFlex = 62;
                      boxFlex = 38;
                    } else if (constraints.maxWidth >= 1000 && constraints.maxHeight >= 620) {
                      imageFlex = 58;
                      boxFlex = 42;
                    } else if (constraints.maxWidth >= 750 && constraints.maxHeight >= 560) {
                      imageFlex = 50;
                      boxFlex = 50;
                    } else if (constraints.maxWidth >= 550 && constraints.maxHeight >= 500) {
                      imageFlex = 44;
                      boxFlex = 56;
                    } else {
                      imageFlex = 35;
                      boxFlex = 65;
                    }

                    final spacerTopFlex = constraints.maxHeight >= 600 ? 4 : 2;
                    final spacerBottomFlex = constraints.maxHeight >= 600 ? 2 : 1;

                    return Column(
                      children: [
                        Text(
                          'Results',
                          style: textTheme.titleLarge!.copyWith(
                            fontSize: 45,
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
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: colorScheme.onSecondary,
                                    width: 3,
                                  ),
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

                        // --- BOX LLM SCROLLABILE ---
                        Expanded(
                          flex: boxFlex, 
                          child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // HEADER
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.orange, width: 3),
                                    ),
                                    child: CircleAvatar(
                                      radius: 26,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage: narratorAsset != null
                                          ? AssetImage(narratorAsset)
                                          : const AssetImage('assets/images/placeholder.png'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      narratorStyle, 
                                      style: textTheme.bodyMedium!.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: colorScheme.onPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // PULSANTE MUTE
                                  IconButton(
                                    icon: Icon(
                                      ttsManager.isMuted ? Icons.volume_off : Icons.volume_up, 
                                      color: colorScheme.onPrimary, 
                                      size: 24
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: _toggleMute,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // CORPO
                              Expanded( 
                                child: showLoading
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(color: colorScheme.onPrimary),
                                            const SizedBox(height: 10),
                                            Text(
                                              loadingMessage,
                                              style: TextStyle(color: colorScheme.onPrimary, fontStyle: FontStyle.italic),
                                            )
                                          ],
                                        ),
                                      )
                                    : SingleChildScrollView( 
                                        controller: _scrollController,
                                        child: Text(
                                          _displayedText, 
                                          style: textTheme.bodyMedium!.copyWith(
                                            fontSize: 20,
                                            color: colorScheme.onPrimary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),   

                      Spacer(flex: spacerTopFlex),

                      if (isHost)
                        SizedBox(
                          width: 200,
                          height: 58,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              disabledBackgroundColor: colorScheme.primary.withAlpha(128), 
                              disabledForegroundColor: colorScheme.onPrimary,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            // Abilita bottone solo se tutto è pronto
                            onPressed: (!showLoading) ? _checkGameStatusAndProceed : null, 
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
                        Text(
                          "Waiting for the host...",
                          style: TextStyle(
                            fontSize: 20,
                            color: colorScheme.onSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),

                      Spacer(flex: spacerBottomFlex),
                    ],
                  );
                },
              ),
            ),
          );
        }
        ),
      )
    );
  }
}