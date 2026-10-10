import 'package:flutter/material.dart';
//import 'package:llm_in_fabula/screens/about_us.dart';
import 'package:llm_in_fabula/screens/onboarding.dart';
import 'create_room_page.dart';
import 'join_room_page.dart';

class HomePage extends StatelessWidget {

  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
     
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0, // Rimuove l'ombra per pulizia
        title: const Text(
          "Home",
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),           
          onPressed: () {
            scaffoldKey.currentState?.openDrawer();         
          },
        ),
      ),

      drawer: Drawer(
        backgroundColor: colorScheme.primary,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Menu',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: colorScheme.secondary),
                ),
              ),
              const Divider(color: Colors.grey),
              
              ListTile(
                leading: Icon(Icons.book, color: colorScheme.secondary),
                title: Text('Guide', style: TextStyle(color: colorScheme.secondary)),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => OnboardingScreen()));
                },
              ),
              /*
              ListTile(
                leading: Icon(Icons.info_outline, color: colorScheme.secondary),
                title: Text('About Us', style: TextStyle(color: colorScheme.secondary)),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AboutUsPage()));
                },
              ),
              */
            ],
          ),
        ),
      ),

      body: SafeArea(
        // 1. FORZA LA LARGHEZZA MASSIMA per garantire il centramento orizzontale
        child: SizedBox(
          width: double.infinity, 
          child: Column(
            // 2. Allinea tutto al centro
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              
              // Spacer superiore per bilanciare il layout verticale
              const Spacer(flex: 2),

              // LOGO (Dimensioni fisse richieste)
              const Image(
                image: AssetImage('assets/images/logo.png'),
                width: 200, 
                height: 200,
                fit: BoxFit.contain,
              ),

              // Distanza Logo - Titolo (ex SizedBox 50 -> Flex 5)
              const Spacer(flex: 5),

              // TITOLO (Dimensione 60)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "LLMs \nin Fabula",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 60,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),

              // Distanza Titolo - Primo Bottone (ex SizedBox 100 -> Flex 10)
              const Spacer(flex: 10),

              // Create Game Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 25)
                ),
                child: const Text(
                  "Create Game",
                  style: TextStyle(fontSize: 25),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CreateRoomPage()),
                  );
                },
              ),

              // Distanza tra i bottoni (ex SizedBox 20 -> Flex 2)
              const Spacer(flex: 2),

              // Join Game Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 25)
                ),
                child: const Text(
                  "Join Game",
                  style: TextStyle(fontSize: 25),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => JoinRoomPage()),
                  );
                },
              ),

              // Spacer inferiore (ex SizedBox 60 -> Flex 6)
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}