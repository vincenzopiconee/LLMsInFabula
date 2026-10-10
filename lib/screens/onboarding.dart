import 'package:flutter/material.dart';

// Onboarding data model
class OnboardingPageData {
  final String image;
  final String title;
  final String subtitle;

  OnboardingPageData({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}

// Tutte le pagine
final List<OnboardingPageData> onboardingData = [
  OnboardingPageData(
    image: 'assets/images/controller.png', 
    title: 'PLAY WITH\nFRIENDS',
    subtitle: 'Create a new virtual room for your friends or join an existing one simply by entering a game code.',
  ),
  OnboardingPageData(
    image: 'assets/images/dice.png',
    title: 'PERSONALIZE\nYOUR EXPERIENCE',
    subtitle: 'Choose the number of players and roles, set discussion and voting times, and pick a Virtual Narrator style for a fully customized experience.',
  ),
  OnboardingPageData(
    image: 'assets/images/sparkles.png',
    title: 'ENHANCE\nYOUR ADVENTURE',
    subtitle: 'The Virtual Narrator enhances your engagement by creating immersive scenarios with dynamic voices based on the chosen character.',
  ),
  OnboardingPageData(
    image: 'assets/images/spectator.png',
    title: 'LEAD FROM\nTHE OUTSIDE',
    subtitle: 'Spectator mode enables you to set up the match, view players\' roles, and oversee the game while staying outside the action.',
  ),
];

// Widget della singola pagina onboarding
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.secondary),
          onPressed: () {
            Navigator.of(context).maybePop();
          },
        ),
        centerTitle: true,
        title: Text(
          'Welcome',
          style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: onboardingData.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, idx) {
                final data = onboardingData[idx];
                return Padding(
                  padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Container(
                        width: 220,
                        height: 220,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Image.asset(
                            data.image,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        data.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.secondary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          data.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.secondary,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              onboardingData.length,
              (index) => Container(
                margin: const EdgeInsets.all(6),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _currentPage == index ? colorScheme.secondary : Colors.white30,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}
