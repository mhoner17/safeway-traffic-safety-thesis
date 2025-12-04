import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'package:safewayproject/explore_page.dart';
import 'package:safewayproject/gpsanimation.dart';
import 'package:safewayproject/main.dart';
import 'package:safewayproject/notification_service.dart';
import 'package:safewayproject/profilePage.dart';

class RiskAlert {
  final Map<String, dynamic> data;
  final List<Map<String, double>> coordinates;
  double distance;

  RiskAlert({
    required this.data,
    required this.coordinates,
    required this.distance,
  });

  String get id => '${data['City']}_${data['Street']}';
}

class LocationRiskChecker extends StatefulWidget {
  const LocationRiskChecker({super.key});

  @override
  State<LocationRiskChecker> createState() => _LocationRiskCheckerState();
}

class _LocationRiskCheckerState extends State<LocationRiskChecker> {
  bool _isTracking = false;
  String _statusMessage = 'Press the button to start real-time tracking';
  final Map<String, RiskAlert> _activeAlerts = {};

  String? _currentCity;
  String? _currentStreet;
  double? _currentLatitude;
  double? _currentLongitude;
  double? _currentSpeed;
  double? _currentAccuracy;
  bool _isDarkMode = false;

  List<dynamic> _riskData = [];
  StreamSubscription<Position>? _positionStreamSubscription;
  final NotificationService _notificationService = NotificationService();
  int _notificationId = 0;

  static const double _searchRadiusMeters = 120.0;

  @override
  void initState() {
    super.initState();
    _loadJsonData();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _clearAllAlerts();
    super.dispose();
  }

  Future<void> _loadJsonData() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/City_Level_Street_Risk.json',
      );
      final data = json.decode(response);
      setState(() {
        _riskData = data;
      });
    } catch (e) {
      print('JSON loading error: $e');
      setState(() {
        _statusMessage = 'Failed to load JSON file: $e';
      });
    }
  }

  List<Map<String, double>> _parseCoordinates(String coordinateString) {
    try {
      final cleaned = coordinateString
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('(', '')
          .replaceAll(')', '');

      final pairs = cleaned.split(', ');
      final List<Map<String, double>> coordinates = [];

      for (int i = 0; i < pairs.length - 1; i += 2) {
        final lat = double.tryParse(pairs[i].trim());
        final lon = double.tryParse(pairs[i + 1].trim());

        if (lat != null && lon != null) {
          coordinates.add({'lat': lat, 'lon': lon});
        }
      }

      return coordinates;
    } catch (e) {
      print('Coordinate parsing error: $e');
      return [];
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _statusMessage =
            'Location services are disabled. Please enable them.';
      });
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _statusMessage = 'Location permissions are denied.';
        });
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _statusMessage =
            'Location permissions are permanently denied.';
      });
      return false;
    }

    return true;
  }

  Future<void> _startLocationTracking() async {
    if (!await _handleLocationPermission()) return;

    setState(() {
      _isTracking = true;
      _statusMessage = 'Real-time tracking active...';
    });

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _updateLocation,
      onError: (error) {
        setState(() {
          _statusMessage = 'Error: $error';
        });
      },
    );
  }

  void _stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _clearAllAlerts();
    setState(() {
      _isTracking = false;
      _statusMessage = 'Tracking stopped';
    });
  }

  Future<void> _updateLocation(Position position) async {
    setState(() {
      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;
      _currentSpeed = position.speed;
      _currentAccuracy = position.accuracy;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentCity =
              place.administrativeArea ?? place.locality ?? 'Unknown';
          _currentStreet =
              place.thoroughfare ?? place.street ?? 'Unknown';
        });
      }
    } catch (e) {
      print('Geocoding error: $e');
    }

    _searchNearbyRisks(position.latitude, position.longitude);
  }

  void _searchNearbyRisks(double currentLat, double currentLon) {
    try {
      final List<
          MapEntry<
              Map<String, dynamic>,
              MapEntry<List<Map<String, double>>, double>>> nearbyRisks = [];

      for (var item in _riskData) {
        final String coordinateString = item['Coordinate_Tuple'] ?? '';
        final List<Map<String, double>> coordinates =
            _parseCoordinates(coordinateString);

        if (coordinates.isEmpty) continue;

        double minDistance = double.infinity;

        for (var coord in coordinates) {
          final double distance = _calculateDistance(
            currentLat,
            currentLon,
            coord['lat']!,
            coord['lon']!,
          );

          if (distance < minDistance) {
            minDistance = distance;
          }
        }

        if (minDistance <= _searchRadiusMeters) {
          nearbyRisks
              .add(MapEntry(item, MapEntry(coordinates, minDistance)));
        }
      }

      nearbyRisks
          .sort((a, b) => a.value.value.compareTo(b.value.value));

      final Set<String> currentRiskIds = nearbyRisks
          .map((e) => '${e.key['City']}_${e.key['Street']}')
          .toSet();

      _activeAlerts.keys
          .where((id) => !currentRiskIds.contains(id))
          .toList()
          .forEach(_removeAlert);

      for (var entry in nearbyRisks) {
        final id = '${entry.key['City']}_${entry.key['Street']}';

        if (!_activeAlerts.containsKey(id)) {
          _addAlert(entry.key, entry.value.key, entry.value.value);
        } else {
          _activeAlerts[id]!.distance = entry.value.value;
        }
      }

      setState(() {
        _statusMessage = _activeAlerts.isEmpty
            ? '✓ Tracking active - No risk data for current location'
            : '⚠️ ${_activeAlerts.length} Risk area(s) detected!';
      });
    } catch (e) {
      print('Search error: $e');
    }
  }

  void _addAlert(
    Map<String, dynamic> riskData,
    List<Map<String, double>> coordinates,
    double distance,
  ) {
    final id = '${riskData['City']}_${riskData['Street']}';

    final alert = RiskAlert(
      data: riskData,
      coordinates: coordinates,
      distance: distance,
    );

    setState(() {
      _activeAlerts[id] = alert;
    });

    // PREMIUM NOTIFICATION LOGIC
    final String riskLevelRaw =
        (riskData['Risk_level'] ?? '').toString().toLowerCase();

    // Low risk için bildirim yok (sadece kartta göster)
    if (riskLevelRaw.contains('low')) {
      return;
    }

    String riskLevelForNotification;
    if (riskLevelRaw.contains('high')) {
      riskLevelForNotification = 'high';
    } else if (riskLevelRaw.contains('medium')) {
      riskLevelForNotification = 'medium';
    } else {
      riskLevelForNotification = 'medium';
    }

    // Toplam kaza sayısını int'e çevir
    final int totalAccidents =
        int.tryParse((riskData['Total_Accidents'] ?? '0').toString()) ?? 0;

    _notificationService.showRiskNotification(
      id: _notificationId++,
      streetName: riskData['Street'] ?? 'Unknown street',
      riskLevel: riskLevelForNotification,
      distanceMeters: distance,
      accidents: totalAccidents,
      payload: 'instant_notification',
    );
  }

  void _removeAlert(String id) {
    setState(() {
      _activeAlerts.remove(id);
    });
  }

  void _clearAllAlerts() {
    _activeAlerts.clear();
  }

  Color _getRiskColor(String? riskLevel) {
    final level = riskLevel?.toLowerCase() ?? '';
    if (level.contains('low')) {
      return Colors.green;
    } else if (level.contains('medium')) {
      return Colors.orange;
    } else if (level.contains('high')) {
      return Colors.red;
    }
    return Colors.grey;
  }

  Color get _textColor => _isDarkMode ? Colors.white : Colors.black;
  Color get _secondaryTextColor =>
      _isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

  @override
  Widget build(BuildContext context) {
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color statusBaseColor = _isTracking
        ? (_activeAlerts.isNotEmpty ? Colors.red : Colors.green)
        : Colors.blue;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Real-Time Location Risk',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isTracking)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Icon(Icons.circle, color: Colors.red, size: 12),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const LoginPage(),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.8, -1),
            end: const Alignment(0.8, 1),
            colors: _isDarkMode
                ? [const Color(0xFF0D47A1), const Color(0xFF000022)]
                : const [
                    Color(0xFF1B63D0),
                    Color(0xFF3D8BF5),
                    Color(0xFFE6EEFF),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HERO
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF42A5F5),
                            Color(0xFF1E88E5),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.gps_fixed_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Stay aware of risky streets around you in real time.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.95),
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 18),

                // STATUS CARD
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [
                            statusBaseColor
                                .withOpacity(_isDarkMode ? 0.45 : 0.25),
                            statusBaseColor
                                .withOpacity(_isDarkMode ? 0.25 : 0.12),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.75),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          if (_isTracking)
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: GpsLoadingAnimation(
                                size: 48,
                                color: Colors.white,
                                duration: const Duration(seconds: 3),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              _statusMessage,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // CURRENT LOCATION CARD
                if (_currentCity != null || _currentStreet != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: _isDarkMode
                              ? Colors.black.withOpacity(0.45)
                              : Colors.white.withOpacity(0.86),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.20),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFF1E88E5),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Your Current Location',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                  ),
                                ),
                              ],
                            ),
                            Divider(
                              color: _secondaryTextColor.withOpacity(0.6),
                            ),
                            if (_currentCity != null)
                              Text(
                                'City: $_currentCity',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _textColor,
                                ),
                              ),
                            const SizedBox(height: 8),
                            if (_currentStreet != null)
                              Text(
                                'Street: $_currentStreet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _textColor,
                                ),
                              ),
                            if (_currentLatitude != null &&
                                _currentLongitude != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Coordinates: ${_currentLatitude!.toStringAsFixed(6)}, '
                                '${_currentLongitude!.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _secondaryTextColor,
                                ),
                              ),
                            ],
                            if (_currentSpeed != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Speed: ${(_currentSpeed! * 3.6).toStringAsFixed(1)} km/h',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _secondaryTextColor,
                                ),
                              ),
                            ],
                            if (_currentAccuracy != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Accuracy: ${_currentAccuracy!.toStringAsFixed(1)} m',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _secondaryTextColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // RISK CARDS
                if (_activeAlerts.isNotEmpty)
                  ListView.builder(
                    itemCount: _activeAlerts.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final alert = _activeAlerts.values.toList()[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildRiskAlertCard(alert),
                      );
                    },
                  ),

                const SizedBox(height: 16),

                // START / STOP BUTTON
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _isTracking ? _stopLocationTracking : _startLocationTracking,
                    style: ElevatedButton.styleFrom(
                      elevation: 4,
                      backgroundColor:
                          _isTracking ? Colors.red : const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: _isTracking
                          ? Row(
                              key: const ValueKey('stop'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.stop_rounded),
                                SizedBox(width: 8),
                                Text(
                                  'Stop Tracking',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('start'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.play_arrow_rounded),
                                SizedBox(width: 8),
                                Text(
                                  'Start Real-Time Tracking',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRiskAlertCard(RiskAlert alert) {
    final riskColor = _getRiskColor(alert.data['Risk_level']);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                riskColor.withOpacity(_isDarkMode ? 0.4 : 0.20),
                riskColor.withOpacity(_isDarkMode ? 0.25 : 0.10),
              ],
            ),
            border: Border.all(
              color: riskColor.withOpacity(0.9),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: riskColor.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      color: riskColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.data['Street'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert.data['City'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 14,
                            color: _secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      alert.data['Risk_level'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.near_me,
                        color: _secondaryTextColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${alert.distance.toStringAsFixed(0)}m away',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Accidents: ${alert.data['Total_Accidents']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: _secondaryTextColor,
                    ),
                  ),
                  Text(
                    'Clusters: ${alert.data['Total_Cluster_Number_DBSCAN']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: _secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// MAIN SCREEN
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    LocationRiskChecker(),
    ExplorePage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor:
              isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          selectedItemColor: const Color(0xFF1E88E5),
          unselectedItemColor: isDarkMode ? Colors.grey[400] : Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map_rounded),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_2_outlined),
              activeIcon: Icon(Icons.person_2),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
