import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_handler.dart';
import 'deadzone_engine.dart';
import 'login_screen.dart';
import 'home_map_screen.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _highContrast = false;
  bool _proximityActive = true;
  bool _performanceMode = false;

  ThemeMode get themeMode => _themeMode;
  bool get highContrast => _highContrast;
  bool get proximityActive => _proximityActive;
  bool get performanceMode => _performanceMode;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void toggleHighContrast(bool hc) {
    _highContrast = hc;
    notifyListeners();
  }

  void toggleProximity(bool pa) {
    _proximityActive = pa;
    notifyListeners();
  }

  void togglePerformanceMode(bool pm) {
    _performanceMode = pm;
    notifyListeners();
  }
}

final themeNotifier = ThemeNotifier();

late AuthHandler authHandler;
late DeadzoneEngine deadzoneEngine;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    authHandler = await AuthHandler.initialize(
      sessionStore: SharedPrefsSessionStore(),
    );
    deadzoneEngine = await DeadzoneEngine.initialize(
      congestionTtl: const Duration(minutes: 30),
    );
    
    // Automatically log into dev sandbox if not authenticated
    if (!authHandler.isAuthenticated) {
      await authHandler.signInWithDevSandbox();
    }
    
    runApp(const MetroOneApp());
  } catch (e, stackTrace) {
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              'Fatal Initialization Error:\n\n$e\n\n$stackTrace',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ),
      ),
    ));
  }
}

class MetroOneApp extends StatelessWidget {
  const MetroOneApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeNotifier,
      builder: (context, _) {
        return MaterialApp(
          title: 'Disha',
          debugShowCheckedModeBanner: false,
          themeMode: themeNotifier.themeMode,
          theme: themeNotifier.highContrast 
            ? ThemeData.light().copyWith(
                primaryColor: Colors.black,
                scaffoldBackgroundColor: Colors.white,
                cardColor: Colors.white,
                appBarTheme: const AppBarTheme(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 4),
                colorScheme: const ColorScheme.light(primary: Colors.black, secondary: Colors.black),
              )
            : ThemeData.light().copyWith(
                primaryColor: const Color(0xFF1b775f),
                scaffoldBackgroundColor: const Color(0xFFF2F2F7),
                cardColor: Colors.white,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFFF2F2F7),
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF1b775f),
                  secondary: Color(0xFFc7ee72),
                ),
              ),
          darkTheme: themeNotifier.highContrast
            ? ThemeData.dark().copyWith(
                primaryColor: Colors.yellow,
                scaffoldBackgroundColor: Colors.black,
                cardColor: Colors.black,
                appBarTheme: const AppBarTheme(backgroundColor: Colors.yellow, foregroundColor: Colors.black, elevation: 4),
                colorScheme: const ColorScheme.dark(primary: Colors.yellow, secondary: Colors.yellow),
              )
            : ThemeData.dark().copyWith(
                primaryColor: const Color(0xFF1b775f),
                scaffoldBackgroundColor: const Color(0xFF0A0A0C),
                cardColor: const Color(0xFF1C1C1E),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF0A0A0C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF1b775f),
                  secondary: Color(0xFFc7ee72),
                ),
              ),
          home: const HomeMapScreen(),
        );
      }
    );
  }
}