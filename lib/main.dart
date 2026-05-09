import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yellow_yellow_mobile/views/home_screen.dart';
import 'package:yellow_yellow_mobile/views/login_screen.dart';
import 'package:yellow_yellow_mobile/views/registration_screen.dart';

void main() async {
  // Ensure Flutter is ready before we talk to SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();

  // Check if we have a saved login
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;

  runApp(YellowYellowApp(isLoggedIn: isLoggedIn));
}

class YellowYellowApp extends StatelessWidget {
  final bool isLoggedIn;

  const YellowYellowApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yellow Yellow',
      theme: ThemeData(
        primarySwatch: Colors.yellow,
      ),
      // If logged in, go to Home. If not, go to Login.
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}