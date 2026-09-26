import 'package:flutter/material.dart';
import 'complaints_map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MetroOneApp());
}

class MetroOneApp extends StatelessWidget {
  const MetroOneApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Metro One',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueGrey[900],
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blueGrey[900],
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.redAccent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent,
            foregroundColor: Colors.black,
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metro One Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_subway, size: 80, color: Colors.tealAccent),
            const SizedBox(height: 24),
            const Text(
              'Metro Route Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Other core features are implemented here.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ComplaintsMapScreen()),
                );
              },
              icon: const Icon(Icons.map),
              label: const Text('Open Safety Map'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}