import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

class AiStoryGenerator {
  final DatabaseReference roomRef;

  static const String _geminiApiKey =
      'AQ.Ab8RN6Kk8XFs8deZevNu6QFXZow4pcMig73c-fyt5ieJhbna1Q';

  AiStoryGenerator(this.roomRef);

  // --- MAPPA DELLE DESCRIZIONI ---
  // Mappiamo l'ID (il nome salvato nel DB) alla descrizione completa per il prompt.
  static final Map<String, String> _narratorDescriptions = {
    "Bard storyteller": "A classic storyteller weaving an immersive tale with warm, poetic, and descriptive language.",
    "Dark Wizard": "A faceless shadow with an eerie, gothic presence, speaking in cryptic whispers.",
    "Oracle": "A mystical voice delivering prophecies in a slow, rhythmic, and enigmatic tone.",
    "Old folk": "A village member recounting personal events with a simple, direct, and down-to-earth style.",
  };

  /// Genera una storia basata sullo stato attuale della partita.
  Future<void> generateStory(String eventType) async {
    try {
      // 1. SCARICA I DATI ATTUALI DELLA STANZA
      final snapshot = await roomRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.value as Map;
      
      final playersRaw = data['players'];
      final Map<dynamic, dynamic> players = (playersRaw is Map) ? playersRaw : {};
      
      final String nightResult = data['night_result']?.toString() ?? 'nobody';
      final String dayResult = data['day_result']?.toString() ?? 'nobody';
      
      final settings = data['settings'] as Map? ?? {};
      
      // Recuperiamo il NOME del narratore (ID)
      final String narratorId = settings['llmNarrator']?.toString() ?? "Bard storyteller";
      
      // Recuperiamo la DESCRIZIONE associata (Fallback sul Bardo se non trovato)
      final String narratorStyleDescription = _narratorDescriptions[narratorId] ?? 
          "A classic storyteller weaving an immersive tale with warm, poetic, and descriptive language.";

      // 2. CREA IL CONTESTO (CHI È VIVO, CHI È MORTO)
      String statusReport = "PLAYER LIST:\n";
      String recentEventContext = "";

      players.forEach((key, value) {
        if (value is Map) {
          final name = value['name'] ?? 'Unknown';
          final role = value['role'] ?? 'Unknown';
          final isAlive = value['alive'] == true;
          
          if (isAlive && role != 'Spectator') {
            statusReport += "- $name ($role) [ALIVE]\n";
          } else if (!isAlive && role != 'Spectator') {
            statusReport += "- $name ($role) [DEAD]\n";
          }
        }
      });

      // 3. DEFINISCI L'OBIETTIVO DELLA STORIA
      String task = "";

      switch (eventType) {
        case 'intro':
          task = "It is the first night. Introduce the village and the atmosphere of tension. No one has died yet. Introduce the roles involved in the game without revealing their identities.";
          break;

        case 'night_recap':
          if (nightResult == 'nobody' || nightResult == 'saved') {
            task = "It is morning. The wolves tried to attack, but no one died (perhaps the Doctor protected the victim). Describe the relief of the villagers.";
          } else {
            final victimData = players[nightResult] as Map?;
            final victimName = victimData?['name'] ?? "an unfortunate soul";
            task = "It is morning. During the night, the wolves brutally killed $victimName. Describe the crime scene and the spreading fear. Remember never to reveal the identity of the wolves.";
          }
          break;

        case 'day_recap':
          if (dayResult == 'nobody') {
            task = "The village voted but there was a tie or mass abstention. No one is executed. Tension remains high for the coming night.";
          } else {
            final victimData = players[dayResult] as Map?;
            final victimName = victimData?['name'] ?? "the condemned";
            task = "The village decided to execute $victimName at the stake. Even after $victimName's death, remember not to reveal the victim's role. Describe the dramatic execution.";
          }
          break;

        case 'ending':
        case 'victory_werewolves':
          task = "THE WOLVES HAVE WON! They are now in the majority or have killed everyone. Describe the tragic fate of the falling village. Reveals the names of the winning werewolves.";
          break;

        case 'victory_farmers':
          task = "THE VILLAGERS HAVE WON! The last wolf has been eliminated. The village is finally safe. Describe the celebrations and the light shining again. Reveals the names of the winning villagers and their roles.";
          break;
      }

      // 4. PREPARA IL PROMPT PER GEMINI
      // Qui inseriamo sia il NOME che la DESCRIZIONE dello stile
      final prompt = '''
      You are the Narrator of a "Werewolf" (Lupus in Fabula) role-playing game. Always speak in English.
      
      NARRATOR PERSONA: $narratorId
      NARRATION STYLE INSTRUCTION: $narratorStyleDescription
      
      $statusReport
      
      EVENT TO NARRATE:
      $recentEventContext
      $task
      
      Write a short narration (max 40-60 words). Be engaging and immersive according to your persona. 
      Do not use bullet points, lists and any other complex punctuation (like star or underscores), tell a story. 
      Remember that each player's role, even if dead, is secret.
      Remember that player actions during the night, such as investigations or protections, are secret and cannot be revealed.
      Use a language suitable for all audiences without too much complexity.
      ''';

      // 5. CHIAMA GOOGLE AI STUDIO (GEMINI 3.8 FLASH - 100% GRATUITO)
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=$_geminiApiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Gemini API error (${response.statusCode}): ${response.body}');
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = jsonResponse['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('No candidates returned from Gemini: ${response.body}');
      }

      final parts = candidates.first['content']?['parts'] as List?;
      String generatedText = '';
      if (parts != null) {
        for (final p in parts) {
          if (p is Map && p['text'] != null) {
            generatedText += p['text'].toString();
          }
        }
      }
      if (generatedText.trim().isEmpty) {
        generatedText = "The narrator is speechless...";
      }

      // 6. SALVA NEL DATABASE
      String targetNode;
      if (eventType == 'intro') {
        targetNode = 'intro';
      } else if (eventType == 'ending' || eventType == 'victory_werewolves' || eventType == 'victory_farmers') {
        targetNode = 'ending';
      } else {
        targetNode = 'current_story';
      }

      await roomRef.child("generated_stories").update({
        targetNode: generatedText
      });

    } catch (e, stackTrace) {
      // Log the real error so it is visible in the debug console
      // ignore: avoid_print
      print('[AiStoryGenerator] ❌ ERROR generating story for event "$eventType": $e');
      // ignore: avoid_print
      print('[AiStoryGenerator] StackTrace: $stackTrace');

      String targetNode;
      if (eventType == 'intro') {
        targetNode = 'intro';
      } else if (eventType == 'ending' || eventType == 'victory_werewolves' || eventType == 'victory_farmers') {
        targetNode = 'ending';
      } else {
        targetNode = 'current_story';
      }

      // Write both the fallback text AND the error reason into the DB
      // so the game UI can display a meaningful diagnostic.
      await roomRef.child("generated_stories").update({
        targetNode: "⚠️ Narration unavailable.",
        'narrator_error': e.toString(),
      });
    }
  }
}