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
          builder: (_) => LobbyPage(roomId: roomCode, uid: uid),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString().replaceAll('Exception: ', '')}"), backgroundColor: Colors.red),
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
    required double boxWidth,
    required double boxHeight,
  }) {
    return Container(
      width: boxWidth,
      height: boxHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 40,
            color: Color(0xFF022F40),
          ),
          decoration: InputDecoration(
            counterText: "",
            filled: true,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
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
            TextInputFormatter.withFunction(
              (oldValue, newValue) => TextEditingValue(
                text: newValue.text.toUpperCase(),
                selection: newValue.selection,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.primary,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text("Join Game"),
          centerTitle: true,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final horizontalPadding = screenWidth > 900 ? 64.0 : (screenWidth > 600 ? 40.0 : 24.0);
              final isWide = screenWidth >= 600;
              final boxWidth = isWide ? 80.0 : 68.0;
              final boxHeight = isWide ? 84.0 : 74.0;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // NICKNAME SECTION
                    Text(
                      "Your Nickname",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nicknameController,
                      maxLength: 20,
                      style: TextStyle(
                        color: colorScheme.onSecondary,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        counterStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: colorScheme.surface,
                        hintText: "Nickname (max 20 chars)",
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // GAME CODE SECTION
                    Center(
                      
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Game Code",
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onPrimary,
                              fontSize: 25,
                            ),
                          ),
                        ],
                      )
                       
                    ),
                    
                    const SizedBox(height: 16),

                    // LARGER DIGIT BOXES
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCodeTextField(
                            controller: _codeController1,
                            focusNode: _codeFocus1,
                            nextFocus: _codeFocus2,
                            boxWidth: boxWidth,
                            boxHeight: boxHeight,
                          ),
                          const SizedBox(width: 14),
                          _buildCodeTextField(
                            controller: _codeController2,
                            focusNode: _codeFocus2,
                            nextFocus: _codeFocus3,
                            prevFocus: _codeFocus1,
                            boxWidth: boxWidth,
                            boxHeight: boxHeight,
                          ),
                          const SizedBox(width: 14),
                          _buildCodeTextField(
                            controller: _codeController3,
                            focusNode: _codeFocus3,
                            nextFocus: _codeFocus4,
                            prevFocus: _codeFocus2,
                            boxWidth: boxWidth,
                            boxHeight: boxHeight,
                          ),
                          const SizedBox(width: 14),
                          _buildCodeTextField(
                            controller: _codeController4,
                            focusNode: _codeFocus4,
                            prevFocus: _codeFocus3,
                            boxWidth: boxWidth,
                            boxHeight: boxHeight,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 70),

                    // LARGER JOIN BUTTON
                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleJoin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.secondary,
                            foregroundColor: colorScheme.onSecondary,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: colorScheme.onSecondary)
                              : Text(
                                  "Join Game",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSecondary,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}