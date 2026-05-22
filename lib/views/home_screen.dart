import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import '../services/api_service.dart';
import 'dart:async';
import 'dart:io'; 
import 'package:socket_io_client/socket_io_client.dart' as IO;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userPhone;
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  IO.Socket? _socket;
  LatLng? _destinationLocation;
  String _destinationName = '';
  Position? _currentPassengerPosition; 

  // Structural fix variable: Anchors trip payload data across location stream overrides
  Map<String, dynamic>? _activeTripData;

  static const CameraPosition _accraCentral = CameraPosition(
    target: LatLng(5.6037, -0.1870),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadUserData();
    _listenToLocation();
    _initWebSocket();
  }

  void _initWebSocket() {
    final String activeUrl = Platform.isAndroid 
        ? 'http://10.0.2.2:5005' 
        : 'http://127.0.0.1:5005';

    print('[WebSocket] Connecting to backend at: $activeUrl');

    _socket = IO.io(activeUrl, IO.OptionBuilder()
      .setTransports(['websocket']) 
      .enableAutoConnect()
      .build());

    _socket?.onConnect((_) {
      print('[WebSocket] Connected to backend successfully. ID: ${_socket?.id}');
    });

    _socket?.on('new_trip_requested', (data) {
      print('[WebSocket] Incoming Live Trip Request: $data');
      _handleIncomingTripBroadcast(data);
    });

    _socket?.on('trip_status_updated', (data) {
      print('[WebSocket] Trip Status Change Event: $data');
      _handleTripStatusUpdate(data);
    });

    _socket?.onDisconnect((_) {
      print('[WebSocket] Disconnected from backend server.');
    });
  }

  void _listenToLocation() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) async {
          _currentPassengerPosition = position; 

          if (_userPhone != null && _userPhone != 'Unknown User') {
            try {
              await _apiService.updateLocation(
                _userPhone!,
                position.latitude,
                position.longitude,
              );

              // If an active trip is processing, stop pulling general driver arrays
              if (_activeTripData != null) {
                return;
              }

              final List<dynamic> driverList = await _apiService
                  .getAvailableDrivers();

              setState(() {
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
        });
  }

  double _calculatePrice(LatLng start, LatLng end) {
    double distanceInMeters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    double baseFare = 5.0;
    double perKmRate = 2.0;
    double distanceInKm = distanceInMeters / 1000;
    return baseFare + (distanceInKm * perKmRate);
  }

  void _showRideRequestSheet(Position currentPosition) {
    if (_destinationLocation == null) return;

    double estimatedPrice = _calculatePrice(
      LatLng(currentPosition.latitude, currentPosition.longitude),
      _destinationLocation!,
    );

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trip Summary',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.yellow[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _destinationName,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimated Fare:', style: TextStyle(fontSize: 16)),
                  Text(
                    'GHS ${estimatedPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[700],
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _sendRideRequest(currentPosition, estimatedPrice);
                  },
                  child: const Text(
                    'Confirm Yellow Yellow',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendRideRequest(Position currentPosition, double price) async {
    if (_userPhone == null || _destinationLocation == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _apiService.requestTrip(
        passengerPhone: _userPhone!,
        pickupLat: currentPosition.latitude,
        pickupLng: currentPosition.longitude,
        destLat: _destinationLocation!.latitude,
        destLng: _destinationLocation!.longitude,
        price: price,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); 

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride requested successfully! Waiting for driver...'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); 
      
      print('Error sending ride request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to request ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) return;

    print('Searching for target route destination: $query');
    
    LatLng selectedTargetCoord = const LatLng(5.6508, -0.1862);
    String normalizedQuery = query.toLowerCase().trim();

    if (normalizedQuery.contains('madina')) {
      selectedTargetCoord = const LatLng(5.6696, -0.1657);
    } else if (normalizedQuery.contains('legon')) {
      selectedTargetCoord = const LatLng(5.6508, -0.1862);
    }

    setState(() {
      _destinationLocation = selectedTargetCoord;
      _destinationName = query;

      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: selectedTargetCoord,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination', snippet: query),
        ),
      );
    });

    _moveCameraTo(selectedTargetCoord);

    if (_currentPassengerPosition != null) {
      _showRideRequestSheet(_currentPassengerPosition!);
    } else {
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _showRideRequestSheet(currentPosition);
    }
  }

  void _moveCameraTo(LatLng position) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 14.5));
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _searchController.dispose();
    _socket?.disconnect();
    _socket?.dispose();
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
      key: _scaffoldKey, 
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.yellow[700]),
              accountName: const Text('Yellow Yellow User', style: TextStyle(color: Colors.black)),
              accountEmail: Text(_userPhone ?? '', style: const TextStyle(color: Colors.black54)),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.black),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cached, color: Colors.blue),
              title: const Text('Toggle Role (Test Tool)', style: TextStyle(color: Colors.blue)),
              subtitle: const Text('Switch between Driver and Passenger'),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                String currentRole = prefs.getString('user_type') ?? 'PASSENGER';
                String newRole = (currentRole == 'PASSENGER') ? 'DRIVER' : 'PASSENGER';
                
                await prefs.setString('user_type', newRole);
                Navigator.pop(context); 
                
                setState(() {
                  _activeTripData = null;
                  _polylines.clear();
                  _markers.clear();
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Testing Mode: Active role changed to $newRole'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
            const Divider(),
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
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              print("Map Controller Initialized");
            },
          ),
          
          Positioned(
            top: 0,
            left: 15,
            right: 15,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black87),
                      onPressed: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Where to?',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (value) {
                          _handleSearch(value);
                        },
                      ),
                    ),
                    Icon(Icons.search, color: Colors.yellow[700]),
                    const SizedBox(width: 15),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleIncomingTripBroadcast(dynamic data) async {
    print('[WebSocket LOG] Processing broadcast payload map: $data');
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userType = prefs.getString('user_type') ?? 'PASSENGER'; 

      if (userType != 'DRIVER') {
        print('[WebSocket LOG] Device skipped popup because active role is: $userType');
        return;
      }

      // Explicit mapping of backend payload variables
      String tripId = data['tripId'].toString();
      String passengerPhone = data['passengerPhone'].toString();
      double price = double.parse(data['price'].toString());
      
      // Parse the nested objects directly matching your backend io.emit format
      var pickupData = data['pickup'];
      double pickupLat = double.parse(pickupData['lat'].toString());
      double pickupLng = double.parse(pickupData['lng'].toString());

      print('[WebSocket LOG] Extracted trip details: TripID: $tripId, Lat: $pickupLat, Lng: $pickupLng');

      if (!mounted) return;

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      showDialog(
        context: context,
        barrierDismissible: false, 
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.local_taxi, color: Colors.yellow[800]),
                const SizedBox(width: 10),
                const Text('New Ride Request!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Passenger: $passengerPhone', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text('Offered Fare: GHS ${price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('The pickup location has been highlighted on your interface.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Reject', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700]),
                onPressed: () async {
                  Navigator.pop(context); 
                  try {
                    print('Driver accepting trip request via API: $tripId');
                    await _apiService.acceptTrip(
                      tripId: tripId,
                      driverPhone: _userPhone ?? 'Unknown Driver',
                    );

                    // Fetch active coordinates directly from GPS device hardware
                    Position driverPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

                    setState(() {
                      _activeTripData = Map<String, dynamic>.from(data);
                      _markers.clear();
                      
                      _markers.add(
                        Marker(
                          markerId: const MarkerId('passenger_pickup'),
                          position: LatLng(pickupLat, pickupLng),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                          infoWindow: InfoWindow(title: 'Passenger Location', snippet: 'Phone: $passengerPhone'),
                        ),
                      );

                      _markers.add(
                        Marker(
                          markerId: const MarkerId('driver_location'),
                          position: LatLng(driverPosition.latitude, driverPosition.longitude),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
                          infoWindow: const InfoWindow(title: 'My Location (Driver)'),
                        ),
                      );

                      _polylines.clear();
                      _polylines.add(
                        Polyline(
                          polylineId: const PolylineId('driver_route_to_passenger'),
                          points: [
                            LatLng(driverPosition.latitude, driverPosition.longitude),
                            LatLng(pickupLat, pickupLng),
                          ],
                          color: Colors.blue,
                          width: 6,
                        ),
                      );
                    });

                    _moveCameraTo(LatLng(driverPosition.latitude, driverPosition.longitude));

                  } catch (e) {
                    print('[CRITICAL FRONTEND ERROR - Driver Accept Action]: $e');
                  }
                },
                child: const Text('Accept Ride', style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      );
    } catch (error, stackTrace) {
      print('[CRITICAL FRONTEND ERROR - Incoming Broadcast Parser]: $error');
      print('StackTrace: $stackTrace');
    }
  }

  void _handleTripStatusUpdate(dynamic data) {
    print('[WebSocket LOG] Raw data received from status update payload: $data');
    try {
      String status = data['status'].toString();
      String driverPhone = (data['driverPhone'] ?? 'Unknown Driver').toString();
      
      var driverLoc = data['driverLocation'];
      double driverLat = double.parse(driverLoc['lat'].toString());
      double driverLng = double.parse(driverLoc['lng'].toString());

      if (!mounted) return;

      if (status == 'ACCEPTED') {
        setState(() {
          _activeTripData = Map<String, dynamic>.from(data);
          _markers.clear();
          
          _markers.add(
            Marker(
              markerId: const MarkerId('assigned_driver'),
              position: LatLng(driverLat, driverLng),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
              infoWindow: InfoWindow(title: 'Assigned Driver', snippet: 'Phone: $driverPhone'),
            ),
          );

          if (_destinationLocation != null) {
            _markers.add(
              Marker(
                markerId: const MarkerId('destination'),
                position: _destinationLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(title: 'My Destination', snippet: _destinationName),
              ),
            );

            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route_to_passenger'),
                points: [
                  LatLng(driverLat, driverLng),
                  _destinationLocation!,
                ],
                color: Colors.blue,
                width: 6,
              ),
            );
          }
        });

        _moveCameraTo(LatLng(driverLat, driverLng));
      }
    } catch (error, stackTrace) {
      print('[CRITICAL FRONTEND ERROR - Status Update Window Parser]: $error');
      print('StackTrace: $stackTrace');
    }
  }
}