import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  bool _isGoogleLoading = false;

  void _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _googleSignIn.signOut(); // Force prompt
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        final GoogleSignInAuthentication auth = await account.authentication;
        if (auth.accessToken != null) {
          await authHandler.signInWithAccessToken(auth.accessToken!);
          setState(() {});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully linked Google Account!')));
          }
        }
      }
    } catch (error) {
      debugPrint("Google Sign In Native Error (Firebase missing): $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-in failed (Firebase not configured).\nError: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _isGoogleLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = authHandler.currentUser;
    final isDarkMode = themeNotifier.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('User Profile & Settings'), backgroundColor: const Color(0xFF1b775f), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                      backgroundColor: Colors.grey[300],
                      child: user.photoUrl == null ? const Icon(Icons.person, size: 32, color: Colors.grey) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(user.email, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 24),
          const Text('Account Linkage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
            icon: _isGoogleLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
            label: const Text('Link Google / Gmail Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16)
            ),
          ),
          
          const SizedBox(height: 32),
          const Text('App Settings (UI/UX)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle app-wide dark theme'),
            value: isDarkMode,
            onChanged: (val) {
              themeNotifier.toggleTheme(val);
              setState((){});
            },
            secondary: const Icon(Icons.dark_mode),
          ),
          SwitchListTile(
            title: const Text('High Contrast Mode'),
            subtitle: const Text('Improve text legibility across maps'),
            value: themeNotifier.highContrast,
            onChanged: (val) {
              themeNotifier.toggleHighContrast(val);
              setState((){});
            },
            secondary: const Icon(Icons.contrast),
          ),
          SwitchListTile(
            title: const Text('Live Proximity Notifications'),
            subtitle: const Text('Receive active alerts about train congestion'),
            value: themeNotifier.proximityActive,
            onChanged: (val) {
              themeNotifier.toggleProximity(val);
              setState((){});
            },
            secondary: const Icon(Icons.bluetooth),
          ),
          SwitchListTile(
            title: const Text('Performance Mode (Low Spec)'),
            subtitle: const Text('Disable blur effects to reduce lag'),
            value: themeNotifier.performanceMode,
            onChanged: (val) {
              themeNotifier.togglePerformanceMode(val);
              setState((){});
            },
            secondary: const Icon(Icons.speed),
          ),
        ],
      ),
    );
  }
}
