import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';

// Mobile/desktop-only imports — guarded so web doesn't crash at compile time.
import 'tts_manager_io.dart' if (dart.library.html) 'tts_manager_web.dart'
    as platform;

class TtsManager {
  static final TtsManager _instance = TtsManager._internal();
  factory TtsManager() => _instance;
  TtsManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isMuted = false;

  void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) stop();
  }

  final String _apiUrl =
      'https://texttospeech.googleapis.com/v1beta1/text:synthesize';

  // Latest Gemini TTS model
  static const String _ttsModel = 'gemini-2.5-flash-tts';

  static final Map<String, Map<String, String>> _narratorVoiceConfig = {
    'Bard storyteller': {
      'voiceName': 'Rasalgethi',
      'stylePrompt':
          'Narrate with a charismatic, theatrical, and engaging tone. Speak with energy and clear intonation, like a master storyteller captivating a crowd.',
    },
    'Dark Wizard': {
      'voiceName': 'Charon',
      'stylePrompt':
          'You are a dark wizard that warn a small village, speak in with a mysterious tone trying also to be fast and not think much on pauses.',
    },
    'Oracle': {
      'voiceName': 'Aoede',
      'stylePrompt':
          'Speak with a seamless, unbroken, and majestic flow. Maintain a brisk and decisive pace. Connect your sentences smoothly without pausing, projecting regal confidence and continuous momentum.',
    },
    'Old folk': {
      'voiceName': 'Algenib',
      'stylePrompt':
          'Speak with a gravelly, earthy, and experienced tone. Your voice carries the weight of years but remains strong and direct. Speak with nostalgic conviction and a steady rhythm.',
    },
  };

  /// Generates a TTS audio file and returns its path (or null on failure/web).
  /// On web, returns null and lets the typewriter text carry the narration.
  String _lastWebText = '';
  String _lastWebNarrator = '';

  Future<String?> generateAudioFile(String text, String narratorId) async {
    if (text.trim().isEmpty) return null;
    if (isMuted) return null;

    if (kIsWeb) {
      // Use browser-native SpeechSynthesis: 100% free, zero billing, zero quota limits.
      _lastWebText = text;
      _lastWebNarrator = narratorId;
      return 'web_speech';
    }

    try {
      final config =
          _narratorVoiceConfig[narratorId] ?? _narratorVoiceConfig['Bard storyteller']!;

      final body = {
        'input': {
          'text': text,
          'prompt': config['stylePrompt'],
        },
        'voice': {
          'languageCode': 'en-US',
          'modelName': _ttsModel,
          'name': config['voiceName'],
        },
        'audioConfig': {
          'audioEncoding': 'MP3',
          'speakingRate': 1.0,
          'pitch': 0,
        },
      };

      // On mobile/desktop: use service account auth (safe — not in browser).
      final response = await platform.postWithServiceAccount(
        url: _apiUrl,
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final String audioContent = jsonResponse['audioContent'];
        return await platform.saveTempAudio(audioContent);
      } else {
        print('[TtsManager] ❌ TTS error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('[TtsManager] ❌ TTS exception: $e');
      return null;
    }
  }

  Future<void> playAudioPath(String? path) async {
    if (path == null || isMuted) return;
    await stop();
    if (kIsWeb && path == 'web_speech') {
      platform.speakWeb(_lastWebText, _lastWebNarrator);
      return;
    }
    await _audioPlayer.play(DeviceFileSource(path));
  }

  Future<void> stop() async {
    if (kIsWeb) {
      platform.stopWeb();
    }
    await _audioPlayer.stop();
  }
}

final ttsManager = TtsManager();