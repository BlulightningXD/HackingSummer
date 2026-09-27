import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_handler.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthHandler authHandler;
  const LoginScreen({Key? key, required this.authHandler}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account != null) {
        final GoogleSignInAuthentication auth = await account.authentication;
        if (auth.accessToken != null) {
          final user = await widget.authHandler.signInWithAccessToken(auth.accessToken!);
          if (user != null && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
            return;
          }
        }
      }
    } catch (error) {
      debugPrint("Google Sign In Native Error (Firebase missing): $error");
      final user = await widget.authHandler.signInWithDevSandbox();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
      return;
    }
    setState(() => _isGoogleLoading = false);
  }

  Future<void> _handleSandboxSignIn() async {
    setState(() => _isLoading = true);
    try {
      await widget.authHandler.signInWithDevSandbox();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sandbox error: $error')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF142321), Color(0xFF1b775f)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_subway, size: 100, color: Color(0xFFc7ee72)),
            const SizedBox(height: 20),
            const Text(
              'Disha',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
            const Text(
              'Delhi, in motion',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 60),
            if (_isLoading || _isGoogleLoading)
              const CircularProgressIndicator(color: Color(0xFFc7ee72))
            else ...[
              // Primary Button is now Dev Sandbox for easy local testing
              ElevatedButton.icon(
                onPressed: _handleSandboxSignIn,
                icon: const Icon(Icons.developer_mode),
                label: const Text('Enter App (Dev Sandbox)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFc7ee72),
                  foregroundColor: const Color(0xFF142321),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 8,
                ),
              ),
              const SizedBox(height: 16),
              // Secondary button is real Google Login (requires Firebase)
              OutlinedButton.icon(
                onPressed: _handleGoogleSignIn,
                icon: const Icon(Icons.login),
                label: const Text('Gmail Login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54, width: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
