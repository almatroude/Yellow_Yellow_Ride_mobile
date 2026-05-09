import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import '../services/api_service.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userPhone;
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;
  Set<Marker> _markers = {};

  LatLng? _destinationLocation;
  String _destinationName = '';

  static const CameraPosition _accraCentral = CameraPosition(
    target: LatLng(5.6037, -0.1870),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadUserData();
    _listenToLocation(); // Using the optimized stream instead of the timer
  }

  void _listenToLocation() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
            if (_userPhone != null && _userPhone != 'Unknown User') {
              try {
                await _apiService.updateLocation(
                  _userPhone!,
                  position.latitude,
                  position.longitude,
                );

                final List<dynamic> driverList = await _apiService
                    .getAvailableDrivers();

                setState(() {
                  // Rebuild the marker set
                  _markers = driverList.map((driver) {
                    return Marker(
                      markerId: MarkerId(driver['id'].toString()),
                      position: LatLng(
                        driver['latitude'] as double,
                        driver['longitude'] as double,
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueYellow,
                      ),
                      infoWindow: InfoWindow(
                        title: 'Tricycle',
                        snippet: 'Phone: ${driver['phoneNumber']}',
                      ),
                    );
                  }).toSet();

                  // Re-add destination marker if it exists
                  if (_destinationLocation != null) {
                    _markers.add(
                      Marker(
                        markerId: const MarkerId('destination'),
                        position: _destinationLocation!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                        infoWindow: InfoWindow(
                          title: 'Destination',
                          snippet: _destinationName,
                        ),
                      ),
                    );
                  }
                });
              } catch (e) {
                print('Error updating location: $e');
              }
            }
          },
        );
  }

  Future<void> _handleSearch(String query) async {
  if (query.isEmpty) return;
  
  print('Searching for: $query');
  
  // Coordinates for University of Ghana, Legon
  LatLng legonCoord = const LatLng(5.6508, -0.1862); 

  setState(() {
    _destinationLocation = legonCoord;
    _destinationName = query;
    
    // Add red marker for destination
    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: legonCoord,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destination', snippet: query),
      ),
    );
  });

  // Programmatically move the camera
  _mapController?.animateCamera(
    CameraUpdate.newLatLngZoom(legonCoord, 15.0),
  );
}

  void _moveCameraTo(LatLng position) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15.0));
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userPhone = prefs.getString('user_phone') ?? 'Unknown User';
    });
  }

  Future<void> _checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yellow Yellow'),
        backgroundColor: Colors.yellow[700],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.yellow[700]),
              accountName: const Text(
                'Yellow Yellow User',
                style: TextStyle(color: Colors.black),
              ),
              accountEmail: Text(
                _userPhone ?? '',
                style: const TextStyle(color: Colors.black54),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.black),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _accraCentral,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              print("Map Controller Initialized");
            },
          ),
          Positioned(
            top: 20,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Where to?',
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.yellow[700]),
                ),
                onSubmitted: (value) {
                  _handleSearch(
                    value,
                  ); // This triggers the red pin and camera move
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
