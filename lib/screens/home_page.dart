import 'package:flutter/material.dart';
import 'package:llm_in_fabula/screens/onboarding.dart';
import 'create_room_page.dart';
import 'join_room_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        title: const Text("Home"),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 740;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // LOGO
                      Image(
                        image: const AssetImage('assets/images/logo.png'),
                        width: isWide ? 220 : 180,
                        height: isWide ? 220 : 180,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),

                      // TITOLO
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isWide ? "LLMs in Fabula" : "LLMs \nin Fabula",
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            fontSize: isWide ? 56 : 46,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimary,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      SizedBox(height: isWide ? 48 : 36),

                      // PULSANTI DI AZIONE PRINCIPALI
                      if (isWide)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildActionButton(
                              context: context,
                              icon: Icons.add_circle_outline_rounded,
                              label: "Create Game",
                              subtitle: "Host room & choose narrator",
                              width: 300,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CreateRoomPage()),
                                );
                              },
                            ),
                            const SizedBox(width: 24),
                            _buildActionButton(
                              context: context,
                              icon: Icons.login_rounded,
                              label: "Join Game",
                              subtitle: "Enter code to play with friends",
                              width: 300,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => JoinRoomPage()),
                                );
                              },
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildActionButton(
                              context: context,
                              icon: Icons.add_circle_outline_rounded,
                              label: "Create Game",
                              subtitle: "Host room & choose narrator",
                              width: 300,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CreateRoomPage()),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildActionButton(
                              context: context,
                              icon: Icons.login_rounded,
                              label: "Join Game",
                              subtitle: "Enter code to play with friends",
                              width: 300,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => JoinRoomPage()),
                                );
                              },
                            ),
                          ],
                        ),

                      const SizedBox(height: 30),

                      // PULSANTE GUIDA & REGOLE (bianco come gli altri per coerenza di stile)
                      SizedBox(
                        width: isWide ? 300 : 270,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.secondary,
                            foregroundColor: colorScheme.onSecondary,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => OnboardingScreen()),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                size: 26,
                                color: colorScheme.onSecondary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "How to Play & Role Rules",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required double width,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      height: 82,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.secondary,
          foregroundColor: colorScheme.onSecondary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          children: [
            Icon(icon, size: 30, color: colorScheme.onSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSecondary.withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}