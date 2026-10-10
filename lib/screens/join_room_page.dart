import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lobby_service.dart';
import 'lobby_page.dart';

class JoinRoomPage extends StatefulWidget {
  const JoinRoomPage({super.key});

  @override
  State<JoinRoomPage> createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends State<JoinRoomPage> {
  final _nicknameController = TextEditingController();
  final _codeController1 = TextEditingController();
  final _codeController2 = TextEditingController();
  final _codeController3 = TextEditingController();
  final _codeController4 = TextEditingController();

  final _codeFocus1 = FocusNode();
  final _codeFocus2 = FocusNode();
  final _codeFocus3 = FocusNode();
  final _codeFocus4 = FocusNode();

  final LobbyService _lobbyService = LobbyService();
  bool _isLoading = false; 

  void _handleJoin() async {
    String roomCodeRaw = _codeController1.text +
        _codeController2.text +
        _codeController3.text +
        _codeController4.text;
        
    String roomCode = roomCodeRaw.trim().toUpperCase();
    String nickname = _nicknameController.text.trim();

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a nickname!"), backgroundColor: Colors.red),
      );
      return;
    }

    if (nickname.length > 20) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Nickname too long! Max 20 characters."), backgroundColor: Colors.red),
    );
    return;
  }

    if (roomCode.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter the 4-digit code!"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String uid = await _lobbyService.joinRoom(
        roomId: roomCode,
        nickname: nickname,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Access granted!"), 
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          ),
      );
      
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (_) => LobbyPage(roomId: roomCode, uid: uid)
        )
      );
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error... ${e.toString().replaceAll('Exception: ', '')}"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _codeController1.dispose();
    _codeController2.dispose();
    _codeController3.dispose();
    _codeController4.dispose();
    _codeFocus1.dispose();
    _codeFocus2.dispose();
    _codeFocus3.dispose();
    _codeFocus4.dispose();
    super.dispose();
  }

  Widget _buildCodeTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    FocusNode? prevFocus,
  }) {
    return SizedBox(
      width: 60,
      height: 65,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.text,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF022F40), 
        ),
        decoration: InputDecoration(
          counterText: "", 
          filled: true,
          fillColor: Colors.white, 
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none, 
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 2.0),
          ),
        ),
        onChanged: (value) {
          if (value.length == 1 && nextFocus != null) {
            FocusScope.of(context).requestFocus(nextFocus);
          }
          if (value.isEmpty && prevFocus != null) {
            FocusScope.of(context).requestFocus(prevFocus);
          }
        },
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')), 
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primary,
        resizeToAvoidBottomInset: false, 
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.secondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text("Join Game", style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.secondary)),
        ),
        body: SafeArea( 
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // === LAYOUT DISTRIBUITO CON SPACER ===
                  const Spacer(flex: 1),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Your Nickname",
                      style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.secondary),
                    ),
                  ),
                  
                  const Spacer(flex: 1), // Piccolo spazio

                  TextField(
                    controller: _nicknameController,
                    maxLength: 20, // <--- AGGIUNTO: Blocca input oltre i 20 caratteri
                    style: const TextStyle(color: Colors.black, fontSize: 18),
                    decoration: InputDecoration(
                      //counterText: "", // Nasconde il contatore visivo se preferisci pulizia
                      filled: true,
                      fillColor: Colors.white,
                      hintText: "Enter your nickname",
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const Spacer(flex: 3), // Spazio medio

                  Text(
                    "Game Code",
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  
                  const Spacer(flex: 1), // Piccolo spazio

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCodeTextField(controller: _codeController1, focusNode: _codeFocus1, nextFocus: _codeFocus2),
                      _buildCodeTextField(controller: _codeController2, focusNode: _codeFocus2, nextFocus: _codeFocus3, prevFocus: _codeFocus1),
                      _buildCodeTextField(controller: _codeController3, focusNode: _codeFocus3, nextFocus: _codeFocus4, prevFocus: _codeFocus2),
                      _buildCodeTextField(controller: _codeController4, focusNode: _codeFocus4, prevFocus: _codeFocus3),
                    ],
                  ),

                  const Spacer(flex: 20), // GRANDE SPAZIO che spinge il bottone in fondo

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleJoin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 25)
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator()
                      : const Text("Join Game", style: TextStyle(fontSize: 25)),
                  ),
                  
                  const Spacer(flex: 2), // Margine inferiore
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}