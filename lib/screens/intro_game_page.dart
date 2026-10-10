import 'dart:async';
import 'dart:io'; 
import '../functions/functions.dart';
import '../services/ai_story_generator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:llm_in_fabula/services/tts_manager.dart';
import 'role_reveal_screen.dart';
import '../services/role_data.dart';

class IntroGamePage extends StatefulWidget {
  final String roomId;
  final String uid;

  const IntroGamePage({
    super.key,
    required this.roomId,
    required this.uid,
  });

  @override
  State<IntroGamePage> createState() => _IntroGamePageState();
}

class _IntroGamePageState extends State<IntroGamePage> {
  late DatabaseReference _roomRef;
  bool _hasNavigatedToRole = false; 
  bool _isGenerating = false; 
  
  // --- NUOVI STATI PER SINCRONIZZAZIONE ---

  bool _isAudioLoading = false; 
  File? _readyAudioFile;
  
  // ----------------------------------------

  // --- TYPEWRITER ---
  String _displayedText = "";
  Timer? _typewriterTimer;
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  // ------------------

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

    _checkAndGenerateIntro();
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

  Future<void> _checkAndGenerateIntro() async {
    final snapshot = await _roomRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.value as Map;
    final adminId = data['adminId'];
    final Map? stories = data['generated_stories'] as Map?;

    if (stories != null && stories['intro'] != null) return;
    if (adminId != widget.uid) return;

    setState(() => _isGenerating = true);
    final aiGen = AiStoryGenerator(_roomRef);
    await aiGen.generateStory('intro'); 
    if (mounted) setState(() => _isGenerating = false);
  }

  void _toggleMute() {
    setState(() {
      ttsManager.toggleMute();
      // Se abbiamo smutato (isMuted è falso) e il file esiste, fallo ripartire
      if (!ttsManager.isMuted && _readyAudioFile != null) {
        ttsManager.playAudioFile(_readyAudioFile!);
      }
    });
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
              icon: Icon(Icons.close, color: Theme.of(context).colorScheme.secondary),
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
            if (snapshot.hasError) return Center(child: Text("Errore: ${snapshot.error}"));
            
            if (snapshot.hasData && snapshot.data!.snapshot.value == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                 if (context.mounted) {
                   ttsManager.stop();
                   Navigator.of(context).popUntil((route) => route.isFirst);
                 }
              });
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final data = snapshot.data!.snapshot.value as Map;
            final settings = data['settings'] as Map? ?? {};
            final String narratorStyle = settings['llmNarrator']?.toString() ?? "Bard storyteller"; 
            final String? narratorAsset = _narratorAssetMap[narratorStyle];
            final String? state = data['state'];
            final String? adminId = data['adminId'];
            
            final Map? stories = data['generated_stories'] as Map?;
            final String? aiIntroText = stories?['intro'];
            final bool isStoryReady = aiIntroText != null && aiIntroText.isNotEmpty;
            final bool amIAdmin = widget.uid == adminId;

            // --- LOGICA SINCRONIZZAZIONE AUDIO + TESTO (PER TUTTI) ---
            // Rimosso controllo 'amIAdmin': ora tutti scaricano l'audio
            if (isStoryReady && !_isAudioLoading && _readyAudioFile == null) {
              
              _isAudioLoading = true; 
              
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                // Scarica per TUTTI (Sync dei tempi di attesa)
                File? audioFile = await ttsManager.generateAudioFile(aiIntroText, narratorStyle);
                
                if (context.mounted) {
                  setState(() {
                    _readyAudioFile = audioFile; 
                    _isAudioLoading = false;     
                  });

                  // Il controllo mute ora è globale dentro ttsManager o qui
                  if (audioFile != null && !ttsManager.isMuted) {
                    ttsManager.playAudioFile(audioFile); 
                  }
                  // Il testo parte sempre
                  _startTypewriter(aiIntroText); 
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
              // Ora tutti vedono questo messaggio mentre l'audio carica
              showLoading = true;
              loadingMessage = "The narrator is clearing their throat...";
            }

            if (state == 'reveal_roles' && !_hasNavigatedToRole) {
              final myData = data['players']?[widget.uid];
              final myRole = myData?['role'] ?? 'Farmer';
              _hasNavigatedToRole = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final roleData = rolesData[myRole] ?? rolesData['Farmer']!;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => RoleRevealScreen(
                    roleName: roleData.name,
                    roleImage: roleData.image,
                    roleDescription: roleData.description,
                    roleColor: roleData.color,
                    roomId: widget.roomId,
                    uid: widget.uid,
                  )),
                );
              });
            }

            return SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Once upon a time...',
                        style: textTheme.titleLarge!.copyWith(fontSize: 40, color: colorScheme.onPrimary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Spacer(flex: 2),
                    

                    Flexible(
                        flex: 35, 
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Container(
                            width: 280,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colorScheme.secondary, width: 3),
                              // SPOSTA L'IMMAGINE QUI DENTRO:
                              image: const DecorationImage(
                                image: AssetImage('assets/images/screen_intro.jpg'),
                                fit: BoxFit.fill, // Usa lo stesso fit che avevi prima
                              ),
                            ),
                            // Rimuovi il child ClipRRect, non serve più
                          ),
                        ),
                      ),

                    const Spacer(flex: 4),

                    // Area Testo / Caricamento
                    Expanded(
                      flex: 65, 
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 24.0),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- HEADER DEL BOX DI TESTO CON BOTTONE MUTE ---
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
                                Expanded( // Usa Expanded per evitare overflow del testo
                                  child: Text(
                                    narratorStyle,
                                    style: textTheme.bodyMedium!.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: colorScheme.onSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // --- PULSANTE MUTE AGGIUNTO QUI ---
                                IconButton(
                                  onPressed: _toggleMute,
                                  icon: Icon(
                                    // Legge lo stato dal singleton
                                    ttsManager.isMuted ? Icons.volume_off : Icons.volume_up,
                                    color: colorScheme.onSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            Expanded(
                              child: showLoading ? 
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: colorScheme.onSecondary),
                                    const SizedBox(height: 10),
                                    Text(
                                      loadingMessage,
                                      style: TextStyle(color: colorScheme.onSecondary),
                                    )
                                  ],
                                ),
                              ) : 
                              SingleChildScrollView(
                                controller: _scrollController,
                                child: Text(
                                  _displayedText,
                                  style: textTheme.bodyMedium!.copyWith(
                                    fontSize: 20,
                                    color: colorScheme.onSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const Spacer(flex: 4),

                    if (amIAdmin)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.secondary,
                          disabledBackgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 25),
                          elevation: 0,
                        ),
                        // Abilita bottone solo se TUTTO è pronto
                        onPressed: (!showLoading) 
                          ? () async {
                              await ttsManager.stop();
                              await _roomRef.update({'state': 'reveal_roles'});
                            } 
                          : null,
                        child: Text(
                          'Continue',
                          style: textTheme.titleMedium!.copyWith(fontSize: 25, color: colorScheme.onSecondary),
                        ),
                      )
                    else
                      Text(
                        "Waiting for the host to continue...",
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    
                    const Spacer(flex: 2),
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