import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF2F3F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.enhanced_encryption_rounded,
                size: 96, color: Color(0xFF0E7A5F)),
            SizedBox(height: 20),
            Text(
              'INTERFLEX',
              style: TextStyle(
                color: Color(0xFF17231E),
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Global transfers. Protected payments.',
              style: TextStyle(
                  color: Color(0xFF60766B), fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 10),
            CircularProgressIndicator(color: Color(0xFF0F9AA7)),
          ],
        ),
      ),
    );
  }
}
