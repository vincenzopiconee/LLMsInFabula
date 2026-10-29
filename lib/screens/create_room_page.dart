import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'lobby_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/lobby_service.dart';

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final TextEditingController nameController = TextEditingController();
  final LobbyService _lobbyService = LobbyService();

  // --- State Variables ---
  bool _isClassicMode = false;
  bool _isSpectator = false;
  
  int _numPlayers = 4;
  List<int> get _playerCountOptions => _isClassicMode
      ? List.generate(26, (index) => index + 5)
      : List.generate(27, (index) => index + 4);

  int get _effectiveRolePlayers => _isClassicMode ? (_numPlayers - 1) : _numPlayers; 

  // Stato per LLM Narrator (Omissis... lista narratori invariata)
  final List<Map<String, dynamic>> _narratorList = [
    {
      "id": "Bard storyteller",
      "description": "A classic storyteller weaving an immersive tale with warm, poetic, and descriptive language.",
      "asset": "assets/images/bard.png",
    },
    {
      "id": "Dark Wizard",
      "description": "A faceless shadow with an eerie, gothic presence, speaking in cryptic whispers.",
      "asset": "assets/images/wizard.png",
    },
    {
      "id": "Oracle",
      "description": "A mystical voice delivering prophecies in a slow, rhythmic, and enigmatic tone.",
      "asset": "assets/images/oracle.png",
    },
    {
      "id": "Old folk",
      "description": "A village member recounting personal events with a simple, direct, and down-to-earth style.",
      "asset": "assets/images/folk.png",
    },
  ];
  
  late String _llmNarrator;

  final Map<String, int> _gameRoles = {
    "Wolves": 1,
    "Seers": 1,
    "Doctors": 1,
    "Medium": 0,
  };
  
  // Opzioni base (verranno filtrate dinamicamente)
  final List<int> _roleCountOptions = [0, 1, 2, 3, 4, 5, 6];
  final List<int> _werewolvesCountOptions = [1, 2, 3, 4, 5, 6];

  String _discussionTime = "5m";
  final List<String> _discussionOptions = ["5m", "7m", "10m"];

  String _votingTime = "2m";
  final List<String> _votingOptions = ["1m", "2m", "5m"];

  String _nightTime = "2m";
  final List<String> _nightTimeOptions = ["1m", "2m", "5m"];

  @override
  void initState() {
    super.initState();
    _llmNarrator = _narratorList.first['id'] as String;
    _calculateBalancedRoles(_numPlayers);
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  /// Bilanciamento ruoli (Invariato)
  void _calculateBalancedRoles(int totalPlayers) {
    int wolves = 1;
    int seers = 0;
    int doctors = 0; 
    int medium = 0;

    final int rolePlayers = _isClassicMode ? (totalPlayers - 1) : totalPlayers;

    if (rolePlayers >= 8) {
      wolves = 2;
      seers = 1;
      doctors = 1; 
      medium = 0;
    }
    if (rolePlayers >= 10) medium = 1;
    if (rolePlayers >= 13) wolves = 3;
    if (rolePlayers >= 17) doctors = 2;
    if (rolePlayers >= 18) wolves = 4;
    if (rolePlayers >= 21) seers = 2;
    if (rolePlayers >= 23) wolves = 5;
    if (rolePlayers >= 26) medium = 2;
    if (rolePlayers >= 28) wolves = 6;

    setState(() {
      _gameRoles["Wolves"] = wolves;
      _gameRoles["Seers"] = seers;
      _gameRoles["Doctors"] = doctors;
      _gameRoles["Medium"] = medium;
      
      // Controllo di sicurezza: se il preset supera il totale (improbabile con la logica sopra, ma utile)
      _checkAndCapRoles();
    });
  }

  /// Funzione per ridurre i ruoli se il totale supera i giocatori (usata quando si cambia il numero totale di giocatori)
  void _checkAndCapRoles() {
    int currentSpecialCount = _gameRoles.values.reduce((a, b) => a + b);
    if (currentSpecialCount > _effectiveRolePlayers) {
      int excess = currentSpecialCount - _effectiveRolePlayers;
      // Riduciamo prima i ruoli opzionali
      for (String key in ["Medium", "Doctors", "Seers", "Wolves"]) {
        if (excess <= 0) break;
        int val = _gameRoles[key]!;
        if (val > 0) {
           // Per i lupi non scendiamo sotto 1
           int minLimit = (key == "Wolves") ? 1 : 0;
           int canReduce = val - minLimit;
           
           if (canReduce > 0) {
             int toReduce = (canReduce >= excess) ? excess : canReduce;
             _gameRoles[key] = val - toReduce;
             excess -= toReduce;
           }
        }
      }
    }
  }

  void _onRoleManuallyChanged(String changedRole, int newValue) {
    setState(() {
      // Impostiamo il nuovo valore
      _gameRoles[changedRole] = newValue;
      
      // Controllo di sicurezza: non dovrebbe servire grazie al filtro nel dropdown, 
      // ma protegge da stati inconsistenti.
      _checkAndCapRoles();
    });
  }

  // --- NUOVA FUNZIONE: Calcola il massimo consentito per un ruolo specifico ---
  int _getMaxAllowedForRole(String roleToCheck) {
    int otherRolesCount = 0;
    
    // Somma tutti i ruoli TRANNE quello che stiamo controllando
    _gameRoles.forEach((key, value) {
      if (key != roleToCheck) {
        otherRolesCount += value;
      }
    });

    // Spazio rimanente = Totale Giocatori - Altri Ruoli
    int remainingSpace = _effectiveRolePlayers - otherRolesCount;
    
    // Non può essere negativo
    return remainingSpace < 0 ? 0 : remainingSpace;
  }

  Future<void> createRoom() async {
    String nickname = nameController.text.trim();

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a nickname to create the game!"), backgroundColor: Colors.red),
      );
      return;
    }

    if (nickname.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nickname too long! Max 20 characters."), backgroundColor: Colors.red),
      );
      return;
    }

    // Mostra la rotella
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final int dbMaxPlayers = _isSpectator ? _numPlayers + 1 : _numPlayers;
      final String? myRole = _isSpectator ? "Spectator" : null;

      // 1. Creazione Stanza
      final roomId = await _lobbyService.createRoom(
        nickname: nameController.text,
        isSpectator: _isSpectator,
        maxPlayers: dbMaxPlayers,
        llmNarrator: _llmNarrator,
        gameRules: _gameRoles,
        timeRules: {
          "discussion": _discussionTime,
          "voting": _votingTime,
          'night': _nightTime
        },
        gameMode: _isClassicMode ? "classic" : "standard",
        roleOverride: myRole,
      );

      // 2. Imposta onDisconnect con TIMEOUT (La modifica è qui)
      // Aspettiamo conferma dal server per MAX 2.5 secondi.
      // Se il server risponde, siamo sicuri al 100%.
      // Se è lento, sblocchiamo comunque l'interfaccia per non bloccare l'utente.
      final roomRef = FirebaseDatabase.instance.ref("rooms/$roomId");
      try {
        await roomRef.onDisconnect().remove().timeout(const Duration(milliseconds: 2500));
        debugPrint("✅ onDisconnect registrato con successo");
      } catch (e) {
        debugPrint("⚠️ onDisconnect lento o fallito (procedo comunque): $e");
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;

      // 3. Chiudi la rotella in sicurezza
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // 4. Naviga
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LobbyPage(roomId: roomId, uid: uid)),
        );
      }

    } catch (e) {
      // Gestione errori generale
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating room: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 900 ? 64.0 : (screenWidth > 600 ? 40.0 : 24.0);

    int specialRolesCount = _gameRoles.values.reduce((a, b) => a + b);
    int villagers = _effectiveRolePlayers - specialRolesCount;
    // Evitiamo numeri negativi visivi se la logica sta aggiornando
    if (villagers < 0) villagers = 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.primary,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text("Create Game Room"),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12.0),
                  children: [
                    const SizedBox(height: 12),
                    _buildClassicModeSwitch(context),
                    const SizedBox(height: 12),
                    _buildSpectatorSwitch(context),
                    const SizedBox(height: 20),
                    _buildNicknameField(context),
                    const SizedBox(height: 20),
                    _buildNumPlayersDropdown(context),
                    
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 20),
                      child: Text(
                        "Farmers: $villagers${_isClassicMode ? ' (+ 1 Narrator)' : ''}",
                        style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                      ),
                    ),

                    if (_isClassicMode)
                      _buildClassicModeInfo(context)
                    else
                      _buildNarratorExpansionTile(context),
                    const SizedBox(height: 20),
                    _buildGameRulesExpansionTile(context),
                    const SizedBox(height: 20),
                    _buildTimeRulesExpansionTile(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              _buildBottomBar(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _onClassicModeChanged(bool val) {
    setState(() {
      _isClassicMode = val;
      if (_isClassicMode && _numPlayers < 5) {
        _numPlayers = 5;
      }
      _calculateBalancedRoles(_numPlayers);
    });
  }

  Widget _buildClassicModeSwitch(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Classic Game",
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 19,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Play with a human Narrator (No AI)",
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          Switch(
            value: _isClassicMode,
            onChanged: _onClassicModeChanged,
            activeTrackColor: theme.colorScheme.secondary,
            activeThumbColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.primary,
            inactiveThumbColor: theme.colorScheme.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildClassicModeInfo(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.secondary, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.record_voice_over, color: theme.colorScheme.secondary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Classic Mode: Human Narrator",
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "One player will be chosen as the Narrator in the lobby.\nTotal players: $_numPlayers (1 Narrator + $_effectiveRolePlayers role players).",
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpectatorSwitch(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Spectator Mode",
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 19,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        Switch(
          value: _isSpectator,
          onChanged: (val) => setState(() => _isSpectator = val),
          activeTrackColor: theme.colorScheme.secondary,
          activeThumbColor: theme.colorScheme.primary,
          inactiveTrackColor: theme.colorScheme.primary,
          inactiveThumbColor: theme.colorScheme.secondary,
        ),
      ],
    );
  }

  Widget _buildNicknameField(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Your Nickname",
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 19,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: nameController,
          maxLength: 20,
          style: TextStyle(color: theme.colorScheme.onSecondary, fontSize: 16),
          decoration: InputDecoration(
            counterStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: theme.colorScheme.surface,
            hintText: "Nickname (max 20 chars)",
            hintStyle: TextStyle(color: Colors.grey.shade600),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildNumPlayersDropdown(BuildContext context) {
    final theme = Theme.of(context);
    final boxDecoration = BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
    );
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSecondary,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Number of Players",
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 19,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        Container(
          width: 55,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: boxDecoration,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _numPlayers,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              dropdownColor: theme.colorScheme.surface,
              style: textStyle,
              onChanged: (int? newValue) {
                if (newValue != null) {
                  setState(() {
                    _numPlayers = newValue;
                    _calculateBalancedRoles(newValue);
                  });
                }
              },
              items: _playerCountOptions.map<DropdownMenuItem<int>>((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  alignment: Alignment.center,
                  child: Text(value.toString()),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameRulesExpansionTile(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      title: Text(
        "Game Roles",
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: 19,
          color: theme.colorScheme.onPrimary,
        ),
      ),
      iconColor: theme.colorScheme.onPrimary,
      collapsedIconColor: theme.colorScheme.onPrimary,
      tilePadding: const EdgeInsets.symmetric(vertical: 2.0),
      children: _gameRoles.keys.map((String role) {
        return _buildRoleRow(
          context,
          role,
          _gameRoles[role]!,
          (newValue) {
            if (newValue != null) {
              _onRoleManuallyChanged(role, newValue);
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildRoleRow(BuildContext context, String role, int currentValue, ValueChanged<int?> onChanged) {
    final theme = Theme.of(context);
    final boxDecoration = BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
    );
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSecondary,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );

    // 1. Calcola il massimo consentito per QUESTO ruolo specifico
    int maxAllowed = _getMaxAllowedForRole(role);

    // 2. Seleziona la lista base (Wolves parte da 1, gli altri da 0)
    final List<int> baseOptions = (role == "Wolves") ? _werewolvesCountOptions : _roleCountOptions;

    // 3. Filtra la lista: mantieni solo i valori <= maxAllowed
    List<int> validOptions = baseOptions.where((val) => val <= maxAllowed).toList();

    if (!validOptions.contains(currentValue)) {
      if (currentValue > maxAllowed) {
         validOptions.add(currentValue);
         validOptions.sort();
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            role,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontSize: 16,
            ),
          ),
          Container(
            width: 55,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: boxDecoration,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: currentValue,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                dropdownColor: theme.colorScheme.surface,
                style: textStyle,
                onChanged: onChanged,
                items: validOptions.map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    alignment: Alignment.center,
                    child: Text(value.toString()),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRulesExpansionTile(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      title: Text(
        "Time Rules",
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: 19,
          color: theme.colorScheme.onPrimary,
        ),
      ),
      iconColor: theme.colorScheme.onPrimary,
      collapsedIconColor: theme.colorScheme.onPrimary,
      tilePadding: const EdgeInsets.symmetric(vertical: 2.0),
      children: [
        _buildTimeRow(context, "Night Time", _nightTime, _nightTimeOptions, (newValue) { if (newValue != null) setState(() => _nightTime = newValue); }),
        _buildTimeRow(context, "Discussion Time", _discussionTime, _discussionOptions, (newValue) { if (newValue != null) setState(() => _discussionTime = newValue); }),
        _buildTimeRow(context, "Voting Time", _votingTime, _votingOptions, (newValue) { if (newValue != null) setState(() => _votingTime = newValue); }),
      ],
    );
  }

  Widget _buildTimeRow(BuildContext context, String label, String currentValue, List<String> options, ValueChanged<String?> onChanged) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSecondary,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontSize: 16,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentValue,
                icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
                dropdownColor: theme.colorScheme.surface,
                style: textStyle,
                onChanged: onChanged,
                items: options.map((String value) => DropdownMenuItem<String>(
                  value: value,
                  alignment: Alignment.center,
                  child: Text(value),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: SizedBox(
        width: 200,
        height: 58,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.secondary,
            foregroundColor: colorScheme.onSecondary,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: createRoom,
          child: Text(
            "Create Game",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNarratorExpansionTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ExpansionTile(
      title: Text(
        "Virtual Narrator",
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: 19,
          color: colorScheme.onPrimary,
        ),
      ),
      iconColor: colorScheme.onPrimary,
      collapsedIconColor: colorScheme.onPrimary,
      tilePadding: const EdgeInsets.symmetric(vertical: 2.0),
      children: _narratorList.map((narrator) {
        final String id = narrator['id'] as String;
        final String desc = narrator['description'] as String;
        final String assetPath = narrator['asset'] as String;
        final bool isSelected = _llmNarrator == id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _llmNarrator = id;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: colorScheme.secondary, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.surface,
                  backgroundImage: AssetImage(assetPath),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        id,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onPrimary,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontStyle: FontStyle.italic,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 10),
                    child: Icon(Icons.check_circle, color: colorScheme.secondary),
                  )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}