import 'dart:async'; 
import 'dart:io'; 
import '../services/ai_story_generator.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import 'package:llm_in_fabula/services/tts_manager.dart'; 

class WerewolvesWinScreen extends StatefulWidget {
  final String roomId;
  final String uid;

  const WerewolvesWinScreen({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<WerewolvesWinScreen> createState() => _WerewolvesWinScreenState();
}

class _WerewolvesWinScreenState extends State<WerewolvesWinScreen> {
  late DatabaseReference _roomRef;
  bool _isGenerating = false;

  // --- STATI PER SINCRONIZZAZIONE AUDIO/TESTO ---
  bool _isAudioLoading = false; 
  File? _readyAudioFile;        
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

    _checkAndGenerateEnding();
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
        ttsManager.playAudioFile(_readyAudioFile!);
      }
    });
  }

  Future<void> _checkAndGenerateEnding() async {
    final snapshot = await _roomRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.value as Map;
    final adminId = data['adminId'];
    final Map? stories = data['generated_stories'] as Map?;

    if (stories != null && stories['ending'] != null) return;
    
    // Se non sono admin, non faccio nulla
    if (adminId != widget.uid) return;

    setState(() => _isGenerating = true);

    final aiGen = AiStoryGenerator(_roomRef);
    // Chiamo il generatore specificando che hanno vinto i lupi
    await aiGen.generateStory('victory_werewolves'); 

    if (mounted) setState(() => _isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.primary,
        // StreamBuilder per ascoltare la chiusura della stanza
        body: StreamBuilder(
          stream: _roomRef.onValue,
          builder: (context, snapshot) {
            
            if (snapshot.hasData && snapshot.data!.snapshot.value == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  ttsManager.stop(); // Stop audio
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("The lobby has been closed by the host."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              });
              return const Center(child: CircularProgressIndicator());
            }
            
            if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final data = snapshot.data!.snapshot.value as Map;
            
            // --- NECESSITIES FOR DISPLAYING LLM TALKING ---
            final settings = data['settings'] as Map? ?? {};
            final String narratorStyle = settings['llmNarrator']?.toString() ?? "Narrator"; 
            final String? narratorAsset = _narratorAssetMap[narratorStyle];
            
            final Map? stories = data['generated_stories'] as Map?;
            final String? aiStoryText = stories?['ending']; 
            final bool isStoryReady = aiStoryText != null && aiStoryText.isNotEmpty;
            // ------------------------------------------------

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
              loadingMessage = _isGenerating 
                  ? "The narrator is writing the ending..." 
                  : "Waiting for the ending...";
            } else if (_isAudioLoading || _readyAudioFile == null) {
              showLoading = true;
              loadingMessage = "The narrator is clearing their throat...";
            }

            return SafeArea(
              child: SizedBox.expand(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      /*
                      Stack(
                        children: [
                          Positioned(
                            top: 6,
                            child: Text(
                              'WEREWOLVES',
                              style: TextStyle(fontSize: 50, fontWeight: FontWeight.w900, foreground: Paint()..color = const Color(0xFF8B0000), letterSpacing: 1),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Text(
                            'WEREWOLVES',
                            style: TextStyle(fontSize: 49, fontWeight: FontWeight.w900, color: colorScheme.onPrimary, letterSpacing: 2),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),

                      */
                      Flexible(
                        flex: 10,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Stack(
                            alignment: Alignment.center, // Assicura allineamento stack
                            children: [
                              Positioned(
                                top: 6,
                                child: Text(
                                  'WEREWOLVES',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 50, 
                                    fontWeight: FontWeight.w900, 
                                    foreground: Paint()..color = const Color(0xFF8B0000), 
                                    letterSpacing: 1
                                  ),
                                ),
                              ),
                              Text(
                                'WEREWOLVES',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 49, 
                                  fontWeight: FontWeight.w900, 
                                  foreground: Paint()..color = colorScheme.onPrimary,
                                  letterSpacing: 2
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Text(
                        'Won',
                        style: textTheme.titleLarge!.copyWith(fontSize: 45, fontWeight: FontWeight.w700, color: colorScheme.onPrimary),
                        textAlign: TextAlign.center,
                      ),

                      const Spacer(flex: 1),

                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF8B0000), width: 8),
                        ),
                        child: const Center(
                          child: Image(image: AssetImage('assets/images/logo.png'), width: 200, height: 200),
                        ),
                      ),

                      const Spacer(flex: 4),

                      Expanded(
                        flex: 40,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(color: colorScheme.secondary, borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                      style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold, fontSize: 20, color: colorScheme.onSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // PULSANTE MUTE
                                  IconButton(
                                    icon: Icon(
                                      ttsManager.isMuted ? Icons.volume_off : Icons.volume_up, 
                                      color: colorScheme.onSecondary, 
                                      size: 24
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: _toggleMute,
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
                                              CircularProgressIndicator(color: colorScheme.onSecondary),
                                              const SizedBox(height: 10),
                                              Text(
                                                loadingMessage,
                                                style: TextStyle(color: colorScheme.onSecondary, fontStyle: FontStyle.italic),
                                              )
                                            ],
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          controller: _scrollController,
                                          child: Text(
                                            _displayedText, // Testo animato
                                            style: textTheme.bodyMedium!.copyWith(fontSize: 20, color: colorScheme.onSecondary, height: 1.4),
                                          ),
                                        ),
                                ),
                            ],
                          ),
                        ),
                      ),      

                      const Spacer(flex: 2),

                      SizedBox(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.secondary,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 25),
                            elevation: 0,
                          ),
                          // Disabilita Exit mentre carica
                          onPressed: (!showLoading) 
                            ? () async {
                              await ttsManager.stop();
                              handleExit(context: context, roomRef: _roomRef, uid: widget.uid);
                            } 
                            : null,
                          child: Text(
                            'Exit Game',
                            style: textTheme.titleMedium!.copyWith(
                              fontSize: 24,
                              color: colorScheme.onSecondary,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      )
    );
  }
}