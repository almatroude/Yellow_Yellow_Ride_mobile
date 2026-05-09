import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Your existing registerUser function...
  Future<bool> registerUser(String phone, String type) async {
    final String activeUrl = Platform.isAndroid
        ? 'http://10.0.2.2:5005'
        : 'http://127.0.0.1:5005';
    try {
      final response = await http
          .post(
            Uri.parse('$activeUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phoneNumber': phone, 'userType': type}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> loginUser(String phone) async {
    final String activeUrl = Platform.isAndroid
        ? 'http://10.0.2.2:5005'
        : 'http://127.0.0.1:5005';
    try {
      final response = await http
          .post(
            Uri.parse('$activeUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phoneNumber': phone.trim(), // Use 'phoneNumber', not 'phone'
            }),
          )
          .timeout(const Duration(seconds: 10));

      // For debugging: Add this line to see what the server is actually saying
      print('Login Status: ${response.statusCode}');
      print('Login Body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('Network Error: $e');
      return false;
    }
  }

  Future<void> updateLocation(String phone, double lat, double lng) async {
    final String activeUrl = Platform.isAndroid
        ? 'http://10.0.2.2:5005'
        : 'http://127.0.0.1:5005';

    try {
      final response = await http
          .patch(
            Uri.parse('$activeUrl/users/location'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phoneNumber': phone,
              'latitude': lat,
              'longitude': lng,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        print('Server rejected location update: ${response.body}');
      }
    } catch (e) {
      print('Heartbeat network error: $e');
    }
  }

  Future<List<dynamic>> getAvailableDrivers() async {
  final String activeUrl = Platform.isAndroid 
      ? 'http://10.0.2.2:5005' 
      : 'http://127.0.0.1:5005';
      
  try {
    final response = await http.get(
      Uri.parse('$activeUrl/users/drivers'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print('Failed to fetch drivers: ${response.body}');
      return [];
    }
  } catch (e) {
    print('Error fetching drivers: $e');
    return [];
  }
}

}
