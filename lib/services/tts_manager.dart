import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:googleapis_auth/auth_io.dart';

class TtsManager {
  static final TtsManager _instance = TtsManager._internal();
  factory TtsManager() => _instance;
  TtsManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isMuted = false; 

  void toggleMute() {
    isMuted = !isMuted;
    // Se l'utente muta mentre l'audio sta andando, lo fermiamo subito.
    if (isMuted) {
      stop();
    }
  }

  final Map<String, dynamic> _serviceAccountConfig = {
    "type": "service_account",
    "project_id": "llminfabula-1", // es. "werewolf-game-123"
    "private_key_id": "60fa912bb1bbc8a1e753813a3b9a4af4d615c29d",
    // LA PRIVATE KEY DEVE CONTENERE I CARATTERI \n ESATTAMENTE COME NEL FILE SCARICATO
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQC4WLMzQjdY0S0/\nqajsRqcsP7BBuK1XXqcZNibW5OIo+pcWdM6eqUwH1HpywUEUTPbbBsKlr8OJrlfm\nHCqu9DXBaoH+RBFl3BjvvpyNBJqWQma2Kxmy6IFc1xB2awksgIcc0pNnU05djhOj\nuaY2q246sPKSGbrwBemSoQGeHsPN6jw7br9pT3rbeypEkTEtBxr81+nghpSEZWlC\nv2xmyiSYpx8D7ICrY0SsfenUwOr9crVH+vdHJdH7iuyNs5Btk5cT+OYjjHioImGA\nunFhIF88b05peoeeT/BF0mCRF0/rqeW2uk7EkzsZwZIuHa1SzLuwUp0G2+PIxhHS\nPtJa6dc3AgMBAAECggEAOSrMm6s/pavsl88Bww/f/MFdY+wk2TDRqehYoBCHsASS\nARVFE//VQ6JZPKgAig6aCO8uQppgjZxCxunaNLonx2zDljm+mXNpSkO2oaaZV9qM\nppZ0GD6xCzzoboif5iyPedk1e/fiF/Ic1guW52I/QzUnbDZNeeyjc+S5LzNELmEb\nNZbhlWI1ayK06IPoP/HTewH8qOi8xM0EAsAERpzPNqZOcwGbsxiZMqr8OA2ky8Bf\nn7qk56qhzpwAkkEC+3bxApIf1luF0c3Jl62eXopHsFYI1jKQ2GJzNFmPMxCRT/ij\nxugDNCYeOoOzXWQtisGXC5g3DVIvgVtCIbWjGmu7OQKBgQDyR2dkqdcrD35MB8j5\nIA8ABjK24BBVBmM5557PXJz0Y/UL8lHbdzn95KsGiHKDiq/U3y3QREuA6r8TEHMP\n8xnxiailFRcyu8cmfnYKN5rpmn4/EM83eLOnvgp0+P2iAW/ShdwAuMu5XKwyUsNE\nDSmnfwfe+DUN0VyfDasZF2e17wKBgQDCyWIJ/w1cASrmjFRsrf+tNuFc9hPc21Si\n2p67rbM1Vt52YuSu+2/BUEbWfLjBlQVa2zW0txEkZw0yWKimqg1c/fOkLThMebqm\nAHtvd6kKgZqvbEbIJVEqGBSPxBBtz+a6jOsNB0Wo6uc8Yndjxksj/58kS1ZkWp98\nhI2d6p/7OQKBgFGxRempYwX/+WQFk/x8lNI7RMppDti8iKSzttbQsZOuSKg4kuVf\ndExp2EkhpQs5rkQm5Lm+7X6QqNDy0PllzS+mbRkM3X+b1XDjX0XerftqvnrhXh2k\nM1+yMrBybIM93MitnhsYNIlR+DYXtgOyNINnz+2c37bDC2oOH80cGTo9AoGAH8vT\nzyHtQlmGcT/zABKfK91LiGs67tB2zma1hpliKZDWm6ik/9NXeMzr41NUrXTv/NbP\nu4IusCyKQO+sCBi2ObnSrbgb+o/cYgCuJZH47Bgf8gbQvxcoWqC3qogszmAjn8wl\nCmlne51sxbSlHIpf9a5iggAySAtrAV55549HMjECgYB5RPH/nKZymMpXyLbECQoG\nWFc+jP/eGNDbeSFWvTDh/mbLeLx629rSi2xRDmzpwDyZMmGGGs89NXrpzGViv/aD\n71YprML9bCBCmzZP2iLrvI3kkhfFma4ZRo3DGrLgLXfIgViDe0A3dakEYYTo/40A\n9BoKk/zWAfGD8D/Is7/mTA==\n-----END PRIVATE KEY-----\n",
    "client_email": "179744805366-compute@developer.gserviceaccount.com", // es. "firebase-adminsdk-..."
    "client_id": "111552661540605499686",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/179744805366-compute%40developer.gserviceaccount.com",
    "universe_domain": "googleapis.com"
  };
  // ⚠️ INSERISCI QUI LA TUA API KEY DI GOOGLE CLOUD
  // Assicurati che l'API "Cloud Text-to-Speech API" sia abilitata nel tuo progetto Google Cloud.

  // URL per le voci Generative (v1beta1)
  final String _apiUrl = "https://texttospeech.googleapis.com/v1beta1/text:synthesize";

  // --- CONFIGURAZIONE VOCI E STILI ---
  // Mappiamo l'ID del narratore (lo stesso usato in ai_story_generator) 
  // a una configurazione specifica per l'audio.
  static final Map<String, Map<String, String>> _narratorVoiceConfig = {
    "Bard storyteller": {
      "voiceName": "Rasalgethi", 
      // PRIMA: "warm, poetic, slow" -> TROPPO LENTO
      // ORA: "charismatic, theatrical, engaging" -> Il Bardo deve intrattenere, non addormentare.
      "stylePrompt": "Narrate with a charismatic, theatrical, and engaging tone. Speak with energy and clear intonation, like a master storyteller captivating a crowd.",
    },
    "Dark Wizard": {
      "voiceName": "Charon", 
      // PRIMA: "slow, whispering, scary" -> TROPPO LENTO
      // ORA: "cold, commanding, ominous" -> Un mago potente non esita. È freddo e diretto.
      "stylePrompt": "You are a dark wizard that warn a small village, speak in with a mysterious tone trying also to be fast and not think much on pauses.",
    },
    "Oracle": {
      "voiceName": "Aoede", 
      // PRIMA: "slow, rhythmic, breathy" -> TROPPO LENTO
      // ORA: "ethereal, mystical, fluid" -> La voce deve scorrere come l'acqua, non fermarsi.
      "stylePrompt": "Speak with a seamless, unbroken, and majestic flow. Maintain a brisk and decisive pace. Connect your sentences smoothly without pausing, projecting regal confidence and continuous momentum.",
    },
    "Old folk": {
      "voiceName": "Algenib", 
      // PRIMA: "tired, slow" -> TROPPO LENTO
      // ORA: "gruff, earthy, direct" -> I vecchi del villaggio sono schietti e vanno al punto.
      "stylePrompt": "Speak with a gravelly, earthy, and experienced tone. Your voice carries the weight of years but remains strong and direct. Speak with nostalgic conviction and a steady rhythm.",
    },
  };

  Future<File?> generateAudioFile(String text, String narratorId) async {
    if (text.trim().isEmpty) return null;

    try {
      final config = _narratorVoiceConfig[narratorId] ?? _narratorVoiceConfig["Bard storyteller"]!;
      
      // Usa l'authClient come prima...
      final accountCredentials = ServiceAccountCredentials.fromJson(_serviceAccountConfig);
      final scopes = ['https://www.googleapis.com/auth/cloud-platform'];
      final authClient = await clientViaServiceAccount(accountCredentials, scopes);

      final body = {
        "input": {
          "text": text,
          "prompt": config["stylePrompt"] 
        },
        "voice": {
          "languageCode": "en-US",
          "modelName": "gemini-3.5-flash-tts", 
          "name": config["voiceName"]
        },
        "audioConfig": {
          "audioEncoding": "MP3",
          "speakingRate": 1, 
          "pitch": 0 
        }
      };

      final response = await authClient.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      authClient.close(); // Chiudi subito il client

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final String audioContent = jsonResponse['audioContent'];
        final bytes = base64.decode(audioContent);

        final dir = await getTemporaryDirectory();
        final fileName = 'tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        
        return file; // Ritorna il file, NON suonarlo ancora
      } else {
        //print("Errore TTS: ${response.body}");
        return null;
      }
    } catch (e) {
      //print("Eccezione TTS: $e");
      return null;
    }
  }

  Future<void> playAudioFile(File file) async {
    // Controllo di sicurezza: se è mutato globalmente, non suonare
    if (isMuted) return; 
    
    await stop();
    await _audioPlayer.play(DeviceFileSource(file.path));
  }

  /// Metodo Speak aggiornato: richiede il testo E l'ID del narratore
  Future<void> speak(String text, String narratorId) async {

    if (isMuted) return;

    if (text.trim().isEmpty) return;

    try {
      await stop();

      final config = _narratorVoiceConfig[narratorId] ?? _narratorVoiceConfig["Bard storyteller"]!;
      
      // 1. Ottieni un Client Autenticato (Token) dal JSON
      final accountCredentials = ServiceAccountCredentials.fromJson(_serviceAccountConfig);
      final scopes = ['https://www.googleapis.com/auth/cloud-platform'];
      
      // Questo client gestisce automaticamente i token e l'autenticazione
      final authClient = await clientViaServiceAccount(accountCredentials, scopes);

      final body = {
        "input": {
          "text": text,
          "prompt": config["stylePrompt"] 
        },
        "voice": {
          "languageCode": "en-US",
          "modelName": "gemini-3.5-flash-tts", 
          "name": config["voiceName"]
        },
        "audioConfig": {
          "audioEncoding": "MP3",
          "speakingRate": 1.1, 
          "pitch": 0 
        }
      };

      // 2. Usa authClient invece di http
      final response = await authClient.post(
        Uri.parse(_apiUrl), // Non serve più ?key=... il client usa il token header
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final String audioContent = jsonResponse['audioContent'];
        final bytes = base64.decode(audioContent);

        final dir = await getTemporaryDirectory();
        final fileName = 'tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        await _audioPlayer.play(DeviceFileSource(file.path));
      } else {
        //("Errore Google TTS (${response.statusCode}): ${response.body}");
      }
      
      // Chiudi il client autenticato per liberare risorse
      authClient.close();

    } catch (e) {
      //print("Eccezione TTS: $e");
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }
}

final ttsManager = TtsManager();