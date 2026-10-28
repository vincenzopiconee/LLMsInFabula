import 'dart:async'; 
import '../services/ai_story_generator.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_in_fabula/functions/functions.dart';
import 'package:llm_in_fabula/services/tts_manager.dart'; 

class FarmersWinScreen extends StatefulWidget {
  final String roomId;
  final String uid;

  const FarmersWinScreen({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<FarmersWinScreen> createState() => _FarmersWinScreenState();
}

class _FarmersWinScreenState extends State<FarmersWinScreen> {
  late DatabaseReference _roomRef;
  bool _isGenerating = false;

  // --- STATI PER SINCRONIZZAZIONE AUDIO/TESTO ---
  bool _isAudioLoading = false; 
  String? _readyAudioFile;        
  bool _audioProcessed = false;        
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
        ttsManager.playAudioPath(_readyAudioFile);
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
    
    if (adminId != widget.uid) return;

    setState(() => _isGenerating = true);

    final aiGen = AiStoryGenerator(_roomRef);
    // Qui usiamo l'evento specifico per i contadini
    await aiGen.generateStory('victory_farmers'); 

    if (mounted) setState(() => _isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
        child: Scaffold(
        backgroundColor: colorScheme.secondary,
        // StreamBuilder per ascoltare la chiusura
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

            if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final data = snapshot.data!.snapshot.value as Map;

            final settings = data['settings'] as Map? ?? {};
            final String narratorStyle = settings['llmNarrator']?.toString() ?? "Narrator";
            final String? narratorAsset = _narratorAssetMap[narratorStyle];
            
            final Map? stories = data['generated_stories'] as Map?;
            // Leggiamo dalla chiave 'ending' come nella pagina dei lupi
            final String? aiStoryText = stories?['ending']; 
            final bool isStoryReady = aiStoryText != null && aiStoryText.isNotEmpty;

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

                  if (audioFile != null && !ttsManager.isMuted) {
                    ttsManager.playAudioPath(audioFile);
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
                  ? "The narrator is celebrating..." 
                  : "Waiting for the happy ending...";
            } else if (_isAudioLoading) {
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

                      // Titolo
                      Stack(
                        children: [
                          Positioned(
                            top: 5,
                            child: Text(
                              'FARMERS',
                              style: TextStyle(fontSize: 53, fontWeight: FontWeight.w900, foreground: Paint()..color = const Color(0xFFDACD2B), letterSpacing: 1),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Text(
                            'FARMERS',
                            style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: colorScheme.onSecondary, letterSpacing: 2),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      Text(
                        'Won',
                        style: textTheme.titleLarge!.copyWith(fontSize: 45, fontWeight: FontWeight.w700, color: colorScheme.onSecondary),
                        textAlign: TextAlign.center,
                      ),

                      const Spacer(flex: 1),

                      // Immagine
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFDACD2B), width: 8),
                        ),
                        child: const Center(
                          child: Image(image: AssetImage('assets/images/farmer.png'), width: 200, height: 200),
                        ),
                      ),

                      const Spacer(flex: 4),

                      // LLM Box Dinamico
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
                                      narratorStyle, // Variabile dinamica
                                      style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold, fontSize: 20, color: colorScheme.onPrimary),
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
                                        _displayedText, // Testo animato
                                        style: textTheme.bodyMedium!.copyWith(fontSize: 20, color: colorScheme.onPrimary, height: 1.4),
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),           
                      
                      const Spacer(flex: 2),

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
                          // Disabilita Exit mentre carica, o lascialo abilitato se preferisci uscire subito
                          onPressed: (!showLoading) 
                            ? () async {
                              await ttsManager.stop();
                              handleExit(context: context, roomRef: _roomRef, uid: widget.uid);
                            } 
                            : null,
                          child: Text(
                            'Exit Game',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary,
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