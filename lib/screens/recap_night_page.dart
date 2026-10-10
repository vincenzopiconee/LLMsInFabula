import 'dart:async';
import 'dart:io'; 
import '../services/ai_story_generator.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import 'package:llm_in_fabula/services/tts_manager.dart'; 

// Import delle pagine di destinazione
import 'discussion_time_page.dart';
import 'dead_role_screen.dart';
import 'spectator_game_screen_day.dart';
import 'werewolf_victory_screen.dart';
import 'farmer_victory_screen.dart';

class RecapNightPage extends StatefulWidget {
  final String roomId;
  final String uid;

  const RecapNightPage({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<RecapNightPage> createState() => _RecapNightPageState();
}

class _RecapNightPageState extends State<RecapNightPage> {
  late DatabaseReference _roomRef;
  bool _hasNavigated = false;
  bool _isGenerating = false;

  // --- STATI PER SINCRONIZZAZIONE ---
  bool _isAudioLoading = false; 
  File? _readyAudioFile;        
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

  void _toggleMute() {
    setState(() {
      ttsManager.toggleMute();
      if (!ttsManager.isMuted && _readyAudioFile != null) {
        ttsManager.playAudioFile(_readyAudioFile!);
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
    await aiGen.generateStory('night_recap'); 

    if (mounted) setState(() => _isGenerating = false);
  }

  Future<void> _checkWinConditionsAndProceed() async {
    await ttsManager.stop(); 

    final snapshot = await _roomRef.get();
    if (!snapshot.exists) return;

    await _roomRef.child('generated_stories/current_story').remove();

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

        if (isAlive && role != 'Spectator') {
          if (role == 'Werewolf') {
            wolvesCount++;
          } else {
            goodGuysCount++;
          }
        }
      }
    });

    if (wolvesCount == 0) {
      await AiStoryGenerator(_roomRef).generateStory('victory_farmers');
      await _roomRef.update({'state': 'victory_farmers'});
    } else if (wolvesCount >= goodGuysCount) {
      await AiStoryGenerator(_roomRef).generateStory('victory_werewolves');
      await _roomRef.update({'state': 'victory_werewolves'});
    } else {
      final settings = data['settings'] != null ? Map<String, dynamic>.from(data['settings']) : {};
      final timeRules = settings['timeRules'] != null ? Map<String, dynamic>.from(settings['timeRules']) : {};
      final String discussionTimeStr = timeRules['discussion'] ?? "5m";
      
      int durationSeconds = 300; 
      if (discussionTimeStr.contains('m')) {
        durationSeconds = int.parse(discussionTimeStr.replaceAll(RegExp(r'[^0-9]'), '')) * 60;
      } else if (discussionTimeStr.contains('s')) {
        durationSeconds = int.parse(discussionTimeStr.replaceAll(RegExp(r'[^0-9]'), ''));
      }

      await _roomRef.update({
        'state': 'discussion',
        'timer': {
          'startTime': ServerValue.timestamp,
          'duration': durationSeconds
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
          leading: null, 
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
                  ttsManager.stop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Room closed."), backgroundColor: Colors.red));
                }
              });
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final data = snapshot.data!.snapshot.value as Map;
            final settings = data['settings'] as Map? ?? {};
            final String narratorStyle = settings['llmNarrator']?.toString() ?? "Narrator"; 
            final String? narratorAsset = _narratorAssetMap[narratorStyle];
            final Map? stories = data['generated_stories'] as Map?;
            final String? aiStoryText = stories?['current_story']; 
            final bool isStoryReady = aiStoryText != null && aiStoryText.isNotEmpty;

            final adminId = data['adminId'];
            final String currentState = data['state'] ?? '';
            final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
            final bool isHost = (adminId == widget.uid);

            // --- LOGICA SINCRONIZZAZIONE ---
            if (isStoryReady && !_isAudioLoading && _readyAudioFile == null) {
              _isAudioLoading = true;
              
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                File? audioFile = await ttsManager.generateAudioFile(aiStoryText, narratorStyle);
                
                if (context.mounted) {
                  setState(() {
                    _readyAudioFile = audioFile;
                    _isAudioLoading = false;
                  });

                  if (audioFile != null && !ttsManager.isMuted) {
                    ttsManager.playAudioFile(audioFile);
                  }
                  _startTypewriter(aiStoryText);
                }
              });
            }

            // --- GESTIONE STATI DI CARICAMENTO ---
            bool showLoading = false;
            String loadingMessage = "";

            if (!isStoryReady) {
              showLoading = true;
              loadingMessage = _isGenerating ? "The narrator is writing..." : "Waiting for the narrator...";
            } else if (_isAudioLoading || _readyAudioFile == null) {
              showLoading = true;
              loadingMessage = "The narrator is clearing their throat...";
            }

            if (!_hasNavigated) {
              // ... LOGICA NAVIGAZIONE ...
              if (currentState == 'discussion') {
                  _hasNavigated = true;
                  final myData = playersMap[widget.uid];
                  final bool amIAlive = myData?['alive'] ?? true;
                  final String myRole = myData?['role'] ?? 'Farmer';

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (myRole == 'Spectator') {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SpectatorFormScreenDay(roomId: widget.roomId, uid: widget.uid)));
                    } else if (amIAlive) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DiscussionTimePage(roomId: widget.roomId, uid: widget.uid)));
                    } else {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DeadRoleRevealScreen(roomId: widget.roomId, uid: widget.uid)));
                    }
                  });
              } 
              else if (currentState == 'victory_farmers') {
                  _hasNavigated = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FarmersWinScreen(roomId: widget.roomId, uid: widget.uid)));
                  });
              }
              else if (currentState == 'victory_werewolves') {
                  _hasNavigated = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WerewolvesWinScreen(roomId: widget.roomId, uid: widget.uid)));
                  });
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tonight...', 
                      style: textTheme.titleLarge!.copyWith(
                        fontSize: 45, 
                        fontWeight: FontWeight.w700, 
                        color: colorScheme.onSecondary
                      ), 
                      textAlign: TextAlign.center
                    ),
                    const Spacer(flex: 1),
                    
                    Container(
                      width: 280,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colorScheme.secondary,
                          width: 3,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: const Image(
                          image: AssetImage('assets/images/tonight.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    
                    const Spacer(flex: 4),
                    
                    // BOX LLM 
                    Expanded(
                      flex: 40,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: colorScheme.primary, 
                          borderRadius: BorderRadius.circular(16)
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- HEADER ---
                            Row(
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
                                      fontSize: 20, color: colorScheme.onPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // --- PULSANTE MUTE GLOBALE ---
                                IconButton(
                                  onPressed: _toggleMute,
                                  icon: Icon(
                                    ttsManager.isMuted ? Icons.volume_off : Icons.volume_up,
                                    color: colorScheme.onPrimary,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

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
                                            style: TextStyle(color: colorScheme.onPrimary, fontStyle: FontStyle.italic)
                                          )
                                        ]
                                      )
                                  )
                                  : SingleChildScrollView(
                                    controller: _scrollController,
                                    child: Text(
                                      _displayedText, 
                                      style: textTheme.bodyMedium!.copyWith(
                                        fontSize: 20, 
                                        color: colorScheme.onPrimary, 
                                        height: 1.4
                                      )
                                    )
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),         
                    
                    const Spacer(flex: 2),

                    if (isHost)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            // AGGIUNGI QUESTA RIGA:
                            disabledBackgroundColor: colorScheme.primary.withAlpha(128) , // Esempio: stesso colore ma semi-trasparente
                            // Oppure un colore fisso: Colors.grey.shade800
                            
                            // OPZIONALE: Cambia anche il colore del testo quando è disabilitato
                            disabledForegroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 25),
                            elevation: 0,
                          ),
                          onPressed: (!showLoading) ? _checkWinConditionsAndProceed : null,
                          child: Text(
                            'Continue',
                            style: textTheme.titleMedium!.copyWith(
                              fontSize: 25,
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                              ),
                            ),
                        ),
                      )
                    else 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Text("Waiting for host...", style: TextStyle(color: colorScheme.onSecondary, fontSize: 18, fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      )
    );
  }
}