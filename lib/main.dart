import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SystemChrome.setPreferredOrientations([   //keeps phone always upright
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      
      debugShowCheckedModeBanner: false,
      title: "Lupus Game",
      theme: ThemeData(
        textTheme: GoogleFonts.risqueTextTheme(),
        colorScheme: ColorScheme(
          brightness: Brightness.dark,           // tema scuro o chiaro
          primary: const Color(0xFF022F40),       // colore principale
          onPrimary: const Color(0xFFF0F4F6),                // colore del testo su primary
          secondary: const Color(0xFFF0F4F6),     // colore secondario
          onSecondary: const Color(0xFF022F40),              // testo su secondary
          surface: const Color(0xFFF0F4F6),        // superficie (card, modal, ecc.)
          onSurface: Colors.white,
          error: Colors.red,                       // colore per errori
          onError: Colors.white,
        ),
        // opzionale: override di appBar in base al colorScheme
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFFF0F4F6), // colore dei testi/icone sull'app bar
        ),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _slideTransitionBuilder,
            TargetPlatform.iOS: _slideTransitionBuilder,
          },
        ),
      ),
      home: HomePage(),
    );
  }
}

class _SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Se è una pagina iniziale, nessuna animazione
    if (route.settings.name == Navigator.defaultRouteName) {
      return child;
    }

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0), // parte da destra
        end: Offset.zero,
      ).animate(animation),
      child: child,
    );
  }
}

const _slideTransitionBuilder = _SlidePageTransitionsBuilder();
