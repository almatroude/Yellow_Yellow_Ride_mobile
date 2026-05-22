import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Unified endpoint target pointing to your machine's network interface
  static final String _activeUrl = Platform.isAndroid 
      ? 'http://10.0.2.2:5005' 
      : 'http://127.0.0.1:5005';
  
  Future<bool> registerUser(String phone, String type) async {
    try {
      final response = await http.post(
        Uri.parse('$_activeUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phone, 'userType': type}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('ApiService registerUser Error: $e');
      return false;
    }
  }

  Future<bool> loginUser(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$_activeUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phone.trim()}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('ApiService loginUser Error: $e');
      return false;
    }
  }

  Future<void> updateLocation(String phone, double lat, double lng) async {
    try {
      final response = await http.patch(
        Uri.parse('$_activeUrl/users/location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phone, 'latitude': lat, 'longitude': lng}),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        print('Server rejected location update: ${response.body}');
      }
    } catch (e) {
      print('Heartbeat network error: $e');
    }
  }

  Future<List<dynamic>> getAvailableDrivers() async {
    try {
      final response = await http.get(
        Uri.parse('$_activeUrl/users/drivers'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      print('ApiService getAvailableDrivers Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> requestTrip({
    required String passengerPhone,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
    required double price,
  }) async {
    final url = Uri.parse('$_activeUrl/trips/request'); 
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'passengerPhone': passengerPhone,
          'pickupLat': pickupLat,
          'pickupLng': pickupLng,
          'destLat': destLat,
          'destLng': destLng,
          'price': price,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to submit trip request.');
      }
    } catch (e) {
      print('ApiService requestTrip Exception: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> acceptTrip({
    required String tripId,
    required String driverPhone,
  }) async {
    final url = Uri.parse('$_activeUrl/trips/accept');

    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tripId': tripId,
          'driverPhone': driverPhone,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to accept trip.');
      }
    } catch (e) {
      print('ApiService acceptTrip Exception: $e');
      rethrow;
    }
  }
}