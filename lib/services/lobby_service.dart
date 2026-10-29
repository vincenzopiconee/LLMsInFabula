import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class LobbyService {
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://llminfabula-1-default-rtdb.europe-west1.firebasedatabase.app'
  ).ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Genera un codice stanza breve (4 caratteri) facile da condividere
  String _generateRoomCode() {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  /// Gestisce l'autenticazione anonima se l'utente non è loggato
  Future<String> getOrSignInUser() async {
    if (_auth.currentUser != null) {
      return _auth.currentUser!.uid;
    }
    final userCredential = await _auth.signInAnonymously();
    return userCredential.user!.uid;
  }

  /// Crea la stanza con tutte le configurazioni complesse
  Future<String> createRoom({
    required String nickname,
    required bool isSpectator,
    required int maxPlayers,
    required String llmNarrator,
    required Map<String, int> gameRules,
    required Map<String, String> timeRules,
    String gameMode = "standard",
    // Nuovo parametro opzionale per forzare il ruolo (es. Spectator)
    String? roleOverride,
  }) async {
    
    // 1. Ottieni UID (o logga l'utente)
    final uid = await getOrSignInUser();

    // 2. Genera ID Stanza
    String roomId = _generateRoomCode();

    // 3. Prepara i dati
    final roomData = {
      "adminId": uid,
      "state": "waiting",
      "creationTime": ServerValue.timestamp,
      "settings": {
        "gameMode": gameMode,
        "spectatorMode": isSpectator,
        "maxPlayers": maxPlayers,
        "llmNarrator": llmNarrator,
        "gameRules": gameRules,
        "timeRules": timeRules,
      },
      "players": {
        uid: {
          "name": nickname,
          "alive": true,
          "isHost": true,
          // Se c'è un override (es. Spectator), lo settiamo subito
          if (roleOverride != null) "role": roleOverride,
        }
      }
    };

    // 4. Scrivi su Firebase
    await _dbRef.child("rooms/$roomId").set(roomData);

    return roomId; 
  }

  Future<String> joinRoom({
    required String roomId,
    required String nickname,
  }) async {
    final uid = await getOrSignInUser();
    final cleanRoomId = roomId.trim().toUpperCase();
    final roomRef = _dbRef.child("rooms/$cleanRoomId");

    final snapshot = await roomRef.get();
    
    if (!snapshot.exists) {
      throw Exception("No room found with code: $cleanRoomId");
    }

    final data = snapshot.value as Map;
    final players = (data['players'] is Map) ? (data['players'] as Map) : {};
    final settings = (data['settings'] is Map) ? (data['settings'] as Map) : {};
    final int maxPlayers = settings['maxPlayers'] ?? 8;
    final String state = data['state'] ?? 'waiting';

    final bool alreadyInRoom = players.containsKey(uid);

    if (!alreadyInRoom) {
      if (state != 'waiting') {
        throw Exception("Game is already in progress!");
      }
      if (players.length >= maxPlayers) {
        throw Exception("Room is full! Maximum number of players reached.");
      }
    }

    // Creiamo l'oggetto giocatore standard
    final playerData = {
      "name": nickname,
      "alive": true,
      "isHost": false, 
    };

    await roomRef.child("players/$uid").set(playerData);

    return uid;
  }
}