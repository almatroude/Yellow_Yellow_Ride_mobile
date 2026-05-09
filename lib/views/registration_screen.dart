import 'package:flutter/material.dart';
import 'package:yellow_yellow_mobile/views/home_screen.dart';
import 'package:yellow_yellow_mobile/views/login_screen.dart'; // 1. Add this import
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yellow_yellow_mobile/views/login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _userType = 'PASSENGER';
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  void _handleRegister() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    bool success = await _apiService.registerUser(
      _phoneController.text,
      _userType,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_phone', _phoneController.text);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registration Successful!')));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration Failed. Number may already be in use.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yellow Yellow'),
        backgroundColor: Colors.yellow[700],
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'Yellow Yellow Registration',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Image.asset('assets/Yellow_Yellow.png', height: 150),
              const SizedBox(height: 30),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _userType,
                decoration: const InputDecoration(
                  labelText: 'I am a...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (newValue) => setState(() {
                  _userType = newValue!;
                }),
                items: ['PASSENGER', 'DRIVER']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
              ),
              const SizedBox(height: 30),
              // Main Registration Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow[700],
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'Sign Up',
                        style: TextStyle(color: Colors.black),
                      ),
              ),
              const SizedBox(height: 20),
              // Single Login Redirect Button
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Already have an account? Login here',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
