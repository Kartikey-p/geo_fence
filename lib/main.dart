import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// 🔔 Background FCM handler (TOP LEVEL)
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GeoFenceMapPage(),
    );
  }
}

class GeoFenceMapPage extends StatefulWidget {
  const GeoFenceMapPage({super.key});

  @override
  State<GeoFenceMapPage> createState() => _GeoFenceMapPageState();
}

class _GeoFenceMapPageState extends State<GeoFenceMapPage> {
  GoogleMapController? mapController;
  Position? currentPosition;
  StreamSubscription<Position>? positionStream;

  String statusText = "Checking location...";
  String directionText = "";

  /// Govt disaster center (example)
  final LatLng disasterCenter = const LatLng(28.6139, 77.2090);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setupFirebaseMessaging();
      startTracking();
    });
  }
  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

  /// 🔔 FCM SETUP + TOKEN
  Future<void> setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission();

    final token = await messaging.getToken();
    debugPrint("🔥 FCM TOKEN: $token");

    await messaging.subscribeToTopic("govt_alerts");

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.notification!.title ?? "Disaster Alert",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  /// 📍 LIVE LOCATION
  Future<void> startTracking() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      final distance = Geolocator.distanceBetween(
        disasterCenter.latitude,
        disasterCenter.longitude,
        pos.latitude,
        pos.longitude,
      );

      String status;
      if (distance <= 300) {
        status = "🚨 EXTREME DANGER ZONE";
      } else if (distance <= 700) {
        status = "⚠️ WARNING ZONE";
      } else {
        status = "✅ SAFE ZONE";
      }

      setState(() {
        currentPosition = pos;
        statusText = status;
        directionText = getDirection(pos);
      });

      mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(pos.latitude, pos.longitude),
        ),
      );
    });
  }

  /// 🧭 Direction
  String getDirection(Position pos) {
    if (pos.latitude >= disasterCenter.latitude &&
        pos.longitude >= disasterCenter.longitude) {
      return "North-East";
    } else if (pos.latitude >= disasterCenter.latitude) {
      return "North-West";
    } else if (pos.longitude >= disasterCenter.longitude) {
      return "South-East";
    } else {
      return "South-West";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Disaster Alert System"),
        backgroundColor: Colors.redAccent,
      ),
      body: Stack(
        children: [
          /// 🗺️ MAP
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: currentPosition != null
                  ? LatLng(
                currentPosition!.latitude,
                currentPosition!.longitude,
              )
                  : disasterCenter,
              zoom: 15,
            ),
            myLocationEnabled: true,
            onMapCreated: (c) => mapController = c,
            circles: {
              Circle(
                circleId: const CircleId("green"),
                center: disasterCenter,
                radius: 1000,
                fillColor: Colors.green.withOpacity(0.2),
                strokeColor: Colors.green,
              ),
              Circle(
                circleId: const CircleId("yellow"),
                center: disasterCenter,
                radius: 700,
                fillColor: Colors.yellow.withOpacity(0.3),
                strokeColor: Colors.yellow,
              ),
              Circle(
                circleId: const CircleId("red"),
                center: disasterCenter,
                radius: 300,
                fillColor: Colors.red.withOpacity(0.4),
                strokeColor: Colors.red,
              ),
            },
            markers: {
              if (currentPosition != null)
                Marker(
                  markerId: const MarkerId("user"),
                  position: LatLng(
                    currentPosition!.latitude,
                    currentPosition!.longitude,
                  ),
                  infoWindow: const InfoWindow(title: "You are here"),
                ),
              const Marker(
                markerId: MarkerId("hospital"),
                position: LatLng(28.6150, 77.2100),
                infoWindow: InfoWindow(title: "Nearest Hospital"),
              ),
            },
          ),

          /// 🔍 ZOOM
          Positioned(
            right: 10,
            top: 120,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: () =>
                      mapController?.animateCamera(CameraUpdate.zoomIn()),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: () =>
                      mapController?.animateCamera(CameraUpdate.zoomOut()),
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          /// 🆘 SOS
          Positioned(
            left: 10,
            top: 120,
            child: FloatingActionButton.extended(
              backgroundColor: Colors.red,
              icon: const Icon(Icons.sos),
              label: const Text("SOS"),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text("Emergency Numbers"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("🚓 Police: 100"),
                        Text("🚑 Ambulance: 108"),
                        Text("🚒 Fire: 101"),
                        Text("🆘 Disaster: 112"),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          /// 📦 INFO PANELS
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  infoBox("STATUS", statusText),
                  infoBox(
                    "📍 LOCATION",
                    currentPosition == null
                        ? "Fetching..."
                        : "Lat: ${currentPosition!.latitude.toStringAsFixed(5)}\n"
                        "Lng: ${currentPosition!.longitude.toStringAsFixed(5)}\n"
                        "Direction: $directionText",
                  ),
                  infoBox(
                    "🏥 NEAREST HOSPITAL",
                    "Alpha Hospital\n1020 meters NORTH WEST",
                  ),
                  infoBox(
                    "📦 SUPPLIES",
                    "🥫 Food – 450m SOUTH\n💊 Medicine – 700m EAST\n🚰 Water – 300m WEST",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget infoBox(String title, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}