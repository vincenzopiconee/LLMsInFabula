import 'package:flutter/material.dart';

class DoctorRoleRevealScreen extends StatelessWidget {
  const DoctorRoleRevealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      backgroundColor: colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: colorScheme.onPrimary, size: 28),
          onPressed: () {
            // Azione menu
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: colorScheme.onPrimary, size: 28),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              
              // "YOU ARE..." text
              Text(
                'YOU ARE A...',
                style: textTheme.titleLarge!.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimary,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 10),
              
              // "DOCTOR" title
              Stack(
                children: [
                  // Shadow/outline effect
                  Positioned(
                    top: 6,                  
                    child: Text(
                      'DOCTOR',
                      style: TextStyle(
                        fontSize: 57,
                        fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..color = const Color(0xFF5A8920),
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Main text
                  Text(
                    'DOCTOR',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onPrimary,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Doctor icon with circle background
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.secondary,

                  border: Border.all(
                    color: const Color(0xFF5A8920),
                    width: 8,
                  ),
                ),
                child: const Center(
                  child: Image(
                    image: AssetImage('assets/images/doctor.png'),
                    width: 220, 
                    height: 220,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Description card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.secondary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'You are the village healer, guardian of life itself. Each night, choose one player to protect from the werewolves\' deadly bite. Your hands hold the power of salvation.',
                  style: textTheme.bodyLarge!.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Continue button
               SizedBox(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 25),
                    elevation: 0,
                  ),
                  onPressed: () {
                  // Azione continuazione
                  },
                  child: Text(
                    'Continue',
                    style: textTheme.titleMedium!.copyWith(
                      fontSize: 24,
                      color: colorScheme.onSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
