// Web implementation — uses the browser's native SpeechSynthesis API.
// 100% free, zero quota limits, no billing account required.
import 'dart:async';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

Future<http.Response> postWithServiceAccount({
  required String url,
  required Map<String, dynamic> body,
}) async {
  throw UnsupportedError('Service account auth is not supported on web.');
}

Future<String?> saveTempAudio(String base64Audio) async {
  return null;
}

Timer? _keepAliveTimer;

html.SpeechSynthesisVoice? _pickVoice(
  List<html.SpeechSynthesisVoice> voices,
  String narratorId,
) {
  if (voices.isEmpty) return null;

  bool matchesName(html.SpeechSynthesisVoice v, String target) {
    final name = v.name?.toLowerCase() ?? '';
    return name.contains(target.toLowerCase());
  }

  // Filter English voices first, fallback to all available voices
  final enVoices = voices.where((v) {
    final lang = v.lang?.toLowerCase() ?? '';
    return lang.startsWith('en');
  }).toList();

  final pool = enVoices.isNotEmpty ? enVoices : voices;

  const maleNames = [
    'daniel', 'alex', 'fred', 'david', 'mark', 'george', 'guy', 'arthur',
    'aaron', 'oliver', 'thomas', 'gordon', 'rishi', 'luca', 'giorgio', 'diego', 'cosimo'
  ];
  const femaleNames = [
    'victoria', 'samantha', 'zira', 'karen', 'moira', 'tessa', 'fiona',
    'jenny', 'aria', 'alice', 'federica', 'paola', 'elsa'
  ];

  bool isVoiceMale(html.SpeechSynthesisVoice v) {
    final name = (v.name ?? '').toLowerCase();
    if (name.contains('female') || name.contains('woman') || name.contains('girl')) {
      return false;
    }
    if (name.contains('male') || name.contains('man') || name.contains('boy')) {
      return true;
    }
    return maleNames.any((m) => name.contains(m));
  }

  bool isVoiceFemale(html.SpeechSynthesisVoice v) {
    final name = (v.name ?? '').toLowerCase();
    if (name.contains('female') || name.contains('woman') || name.contains('girl')) {
      return true;
    }
    return femaleNames.any((f) => name.contains(f));
  }

  switch (narratorId) {
    case 'Dark Wizard': {
      // Sinister, deep male voice: Fred (gravelly), Alex, Daniel, David, etc.
      const preferred = ['fred', 'alex', 'daniel', 'david', 'mark', 'george', 'uk english male'];
      for (final p in preferred) {
        final match = pool.where((v) => matchesName(v, p)).firstOrNull;
        if (match != null) return match;
      }
      return pool.where(isVoiceMale).firstOrNull ?? pool.first;
    }

    case 'Old folk': {
      // Rustic older male voice: Alex, Fred, Daniel, Arthur.
      const preferred = ['alex', 'fred', 'daniel', 'arthur', 'david', 'uk english male'];
      for (final p in preferred) {
        final match = pool.where((v) => matchesName(v, p)).firstOrNull;
        if (match != null) return match;
      }
      return pool.where(isVoiceMale).firstOrNull ?? pool.first;
    }

    case 'Bard storyteller': {
      // Theatrical, lively male voice: Daniel, UK English Male, Arthur, Alex.
      const preferred = ['daniel', 'uk english male', 'alex', 'arthur', 'david', 'guy', 'mark'];
      for (final p in preferred) {
        final match = pool.where((v) => matchesName(v, p)).firstOrNull;
        if (match != null) return match;
      }
      return pool.where(isVoiceMale).firstOrNull ?? pool.first;
    }

    case 'Oracle': {
      // Mystical, regal female voice: Victoria, Samantha, UK English Female, etc.
      const preferred = [
        'victoria', 'samantha', 'uk english female', 'us english', 'zira',
        'jenny', 'aria', 'karen', 'moira', 'tessa'
      ];
      for (final p in preferred) {
        final match = pool.where((v) => matchesName(v, p)).firstOrNull;
        if (match != null) return match;
      }
      return pool.where(isVoiceFemale).firstOrNull ?? pool.first;
    }

    default:
      return pool.first;
  }
}

void speakWeb(String text, String narratorId) {
  try {
    final synth = html.window.speechSynthesis;
    if (synth == null) return;

    _keepAliveTimer?.cancel();
    synth.cancel();

    void executeSpeak() {
      final voices = synth.getVoices();
      final utterance = html.SpeechSynthesisUtterance(text);
      utterance.lang = 'en-US';

      final voice = _pickVoice(voices, narratorId);
      if (voice != null) {
        utterance.voice = voice;
        utterance.lang = voice.lang ?? 'en-US';
      }

      switch (narratorId) {
        case 'Dark Wizard':
          utterance.pitch = 0.5;
          utterance.rate = 0.85;
          break;
        case 'Oracle':
          utterance.pitch = 1.25;
          utterance.rate = 0.92;
          break;
        case 'Old folk':
          utterance.pitch = 0.70;
          utterance.rate = 0.80;
          break;
        case 'Bard storyteller':
        default:
          utterance.pitch = 1.05;
          utterance.rate = 1.05;
          break;
      }

      // Keepalive timer for Chrome 15s synthesis pause issue
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (synth.speaking == true) {
          synth.pause();
          synth.resume();
        } else {
          _keepAliveTimer?.cancel();
          _keepAliveTimer = null;
        }
      });

      utterance.onEnd.listen((_) {
        _keepAliveTimer?.cancel();
        _keepAliveTimer = null;
      });
      utterance.onError.listen((_) {
        _keepAliveTimer?.cancel();
        _keepAliveTimer = null;
      });

      synth.speak(utterance);
    }

    final voices = synth.getVoices();
    if (voices.isEmpty) {
      synth.on['voiceschanged'].first.then((_) => executeSpeak());
    } else {
      executeSpeak();
    }
  } catch (e) {
    // blocked or error
  }
}

void stopWeb() {
  try {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    html.window.speechSynthesis?.cancel();
  } catch (_) {}
}
