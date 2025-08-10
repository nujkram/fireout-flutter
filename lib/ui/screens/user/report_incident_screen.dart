import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart' as loc;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fireout/services/user_incident_service.dart';
// Platform-specific file import is not needed; using XFile for cross-platform

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({Key? key}) : super(key: key);

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final UserIncidentService _incidentService = UserIncidentService();
  final ImagePicker _imagePicker = ImagePicker();

  String? selectedIncidentType;
  loc.LocationData? currentLocation;
  loc.LocationData? selectedLocation;
  // Use XFile to support web and mobile; convert to File only on mobile when needed
  List<XFile> selectedMedia = [];
  bool isSubmitting = false;
  bool isLoadingLocation = false;
  bool showMapPicker = false;
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  
  // Distance limit in meters (2km default)
  static const double maxDistanceFromUser = 2000;
  
  // Default location: Roxas City, Capiz, Philippines
  static const double defaultLatitude = 11.5877;
  static const double defaultLongitude = 122.7519;

  final List<String> incidentTypes = [
    'Fire',
    'Medical Emergency',
    'Traffic Accident',
    'Crime',
    'Natural Disaster',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with Roxas City as default location
    _initializeWithDefaultLocation();
    _requestLocationPermission();
  }
  
  void _initializeWithDefaultLocation() {
    setState(() {
      currentLocation = loc.LocationData.fromMap({
        'latitude': defaultLatitude,
        'longitude': defaultLongitude,
      });
      
      selectedLocation = currentLocation;
      
      print('📍 Initialized with Roxas City default location');
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    final status = await permission_handler.Permission.location.request();
    if (status == permission_handler.PermissionStatus.granted) {
      _getCurrentLocation();
    } else {
      _showLocationPermissionDialog();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => isLoadingLocation = true);
    
    try {
      // Check location service status
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('📍 Location service enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        final locService = loc.Location();
        final enabled = await locService.requestService();
        print('📍 Location service request result: $enabled');
        if (!enabled) {
          setState(() => isLoadingLocation = false);
          _showLocationPermissionDialog();
          return;
        }
      }
      
      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 Current permission: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('📍 Permission after request: $permission');
        if (permission == LocationPermission.denied) {
          setState(() => isLoadingLocation = false);
          _showLocationPermissionDialog();
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() => isLoadingLocation = false);
        _showLocationPermissionDialog();
        return;
      }

      // First try to get the last known position to check if it's reasonable
      try {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          print('📍 Last known position - Lat: ${lastPosition.latitude}, Lng: ${lastPosition.longitude}');
          print('📍 Last position age: ${DateTime.now().difference(lastPosition.timestamp!).inMinutes} minutes old');
        }
      } catch (e) {
        print('📍 No last known position available');
      }
      
      // Get current position with high accuracy and force fresh location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        forceAndroidLocationManager: false, // Use Google Play Services for better accuracy
        timeLimit: const Duration(seconds: 30), // Timeout after 30 seconds
      );
      
      print('📍 Raw GPS Position - Lat: ${position.latitude}, Lng: ${position.longitude}');
      print('📍 Position accuracy: ${position.accuracy} meters');
      print('📍 Position timestamp: ${position.timestamp}');
      
      setState(() {
        // Update current location with GPS data
        currentLocation = loc.LocationData.fromMap({
          'latitude': position.latitude,
          'longitude': position.longitude,
        });
        
        // Update selected location to GPS location (only if user hasn't manually selected a custom location)
        if (_isSelectedLocationCurrentLocation() || selectedLocation == null) {
          selectedLocation = currentLocation;
        }
        
        print('📍 Updated with GPS location - Lat: ${currentLocation!.latitude}, Lng: ${currentLocation!.longitude}');
        print('📍 Selected location - Lat: ${selectedLocation!.latitude}, Lng: ${selectedLocation!.longitude}');
        
        isLoadingLocation = false;
      });
      
      // Show success message for GPS location
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS location obtained successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('📍 GPS location failed, keeping default Roxas City location: $e');
      setState(() {
        isLoadingLocation = false;
      });
      
      // Show a message that GPS failed but we're using default location
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS unavailable. Using Roxas City as default location. You can adjust the location on the map if needed.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location access is required to report incidents accurately. Please enable location permissions in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await permission_handler.openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to get current location. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (image != null) {
        setState(() {
          selectedMedia.add(image);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );
      
      if (video != null) {
        setState(() {
          selectedMedia.add(video);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeMedia(int index) {
    setState(() {
      selectedMedia.removeAt(index);
    });
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.red),
              title: const Text('Record Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitIncident() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedIncidentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an incident type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    // Use selected location if available, otherwise current location
    final locationToUse = selectedLocation ?? currentLocation;
    
    if (locationToUse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is required to submit an incident'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final result = await _incidentService.submitIncident(
        incidentType: selectedIncidentType!,
        latitude: locationToUse!.latitude!,
        longitude: locationToUse!.longitude!,
        mediaFiles: selectedMedia.isNotEmpty ? selectedMedia : null,
        description: _descriptionController.text.trim(),
      );

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident reported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to main screen which will show the appropriate user interface
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/main', 
          (Route<dynamic> route) => false,
        );
      } else {
        throw Exception('Failed to submit incident');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit incident: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  double? _calculateDistanceFromUser(double lat, double lng) {
    if (currentLocation == null) return null;
    
    return Geolocator.distanceBetween(
      currentLocation!.latitude!,
      currentLocation!.longitude!,
      lat,
      lng,
    );
  }

  void _onMapTapped(LatLng location) {
    if (currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current location not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final distance = _calculateDistanceFromUser(location.latitude, location.longitude);
    
    if (distance != null && distance > maxDistanceFromUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location is too far from your current position. Maximum distance is ${(maxDistanceFromUser / 1000).toStringAsFixed(1)} km.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      selectedLocation = loc.LocationData.fromMap({
        'latitude': location.latitude,
        'longitude': location.longitude,
      });
      
      markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: location,
          infoWindow: const InfoWindow(
            title: 'Selected Incident Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
        if (currentLocation != null)
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(
              currentLocation!.latitude!,
              currentLocation!.longitude!,
            ),
            infoWindow: const InfoWindow(
              title: 'Your Current Location',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
      };
    });
  }

  void _resetToCurrentLocation() {
    setState(() {
      selectedLocation = null;
      markers = {};
      showMapPicker = false;
    });
  }

  void _initializeMarkersWithCurrentLocation() {
    setState(() {
      // Use actual current location or default to Roxas City
      final actualLat = currentLocation?.latitude ?? defaultLatitude;
      final actualLng = currentLocation?.longitude ?? defaultLongitude;
      
      // Only set current location as default if no location is selected yet
      if (selectedLocation == null) {
        selectedLocation = loc.LocationData.fromMap({
          'latitude': actualLat,
          'longitude': actualLng,
        });
      }
      
      final selectedLat = selectedLocation?.latitude ?? actualLat;
      final selectedLng = selectedLocation?.longitude ?? actualLng;
      
      // Add markers - current location (blue) and selected incident location (red)
      markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(actualLat, actualLng),
          infoWindow: InfoWindow(
            title: currentLocation != null ? 'Your Current Location' : 'Default Location (Roxas City)',
            snippet: currentLocation != null ? '' : 'GPS location not available',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
        Marker(
          markerId: const MarkerId('selected_location'),
          position: LatLng(selectedLat, selectedLng),
          infoWindow: const InfoWindow(
            title: 'Selected Incident Location',
            snippet: 'Tap to change location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    });
  }

  bool _isSelectedLocationCurrentLocation() {
    if (selectedLocation == null || currentLocation == null) return false;
    
    // Compare coordinates with a small tolerance for floating point precision
    const tolerance = 0.000001;
    return (selectedLocation!.latitude! - currentLocation!.latitude!).abs() < tolerance &&
           (selectedLocation!.longitude! - currentLocation!.longitude!).abs() < tolerance;
  }
  
  bool _isUsingDefaultLocation() {
    if (currentLocation == null) return false;
    
    const tolerance = 0.000001;
    return (currentLocation!.latitude! - defaultLatitude).abs() < tolerance &&
           (currentLocation!.longitude! - defaultLongitude).abs() < tolerance;
  }

  void _moveCameraToCurrentLocation() async {
    if (mapController != null && currentLocation != null) {
      await mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(
            currentLocation!.latitude!,
            currentLocation!.longitude!,
          ),
        ),
      );
    }
  }

  Future<Widget> _buildMapWidget() async {
    try {
      // Initialize markers with user's current location if not already set
      if (markers.isEmpty && currentLocation != null) {
        _initializeMarkersWithCurrentLocation();
      }
      
      // Use selectedLocation, currentLocation, or default to Roxas City for camera position
      final cameraLat = selectedLocation?.latitude ?? 
                       currentLocation?.latitude ?? 
                       defaultLatitude;
      final cameraLng = selectedLocation?.longitude ?? 
                       currentLocation?.longitude ?? 
                       defaultLongitude;
      
      print('🗺️ Map centering on: Lat: $cameraLat, Lng: $cameraLng');
      print('🗺️ Current Location: Lat: ${currentLocation?.latitude}, Lng: ${currentLocation?.longitude}');
      print('🗺️ Selected Location: Lat: ${selectedLocation?.latitude}, Lng: ${selectedLocation?.longitude}');
      
      final map = GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(cameraLat, cameraLng),
          zoom: 15,
        ),
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
          // Move camera to current location after map is created with a slight delay
          Future.delayed(const Duration(milliseconds: 100), () {
            _moveCameraToCurrentLocation();
          });
        },
        onTap: _onMapTapped,
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
        mapType: MapType.normal,
      );
      
      return map;
    } catch (e) {
      print('Error creating Google Map: $e');
      rethrow;
    }
  }

  Widget _buildMapFallback() {
    return Container(
      color: Colors.white.withOpacity(0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.map_outlined,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            'Map Unavailable',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please use your current location\nor enter coordinates manually',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              _showCoordinateInputDialog();
            },
            icon: const Icon(Icons.edit_location),
            label: Text(
              'Enter Coordinates',
              style: GoogleFonts.poppins(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.8),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showCoordinateInputDialog() {
    final TextEditingController latController = TextEditingController();
    final TextEditingController lngController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Enter Coordinates',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g., 14.5995',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lngController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g., 120.9842',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lng = double.tryParse(lngController.text);
              
              if (lat != null && lng != null) {
                final distance = _calculateDistanceFromUser(lat, lng);
                
                if (distance != null && distance > maxDistanceFromUser) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Location is too far from your current position. Maximum distance is ${(maxDistanceFromUser / 1000).toStringAsFixed(1)} km.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                
                setState(() {
                  selectedLocation = loc.LocationData.fromMap({
                    'latitude': lat,
                    'longitude': lng,
                  });
                });
                
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Custom location set successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid coordinates'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Set Location', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        title: Text(
          'Report Incident',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIncidentTypeSection(),
              const SizedBox(height: 20),
              _buildDescriptionSection(),
              const SizedBox(height: 20),
              _buildLocationSection(),
              const SizedBox(height: 20),
              _buildMediaSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncidentTypeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Incident Type *',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: incidentTypes.map((type) {
              final isSelected = selectedIncidentType == type;
              return GestureDetector(
                onTap: () => setState(() => selectedIncidentType = type),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.white.withOpacity(0.3) 
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected 
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: Text(
                    type,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description (Optional)',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Describe the incident in detail...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final locationToUse = selectedLocation ?? currentLocation;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Location *',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (isLoadingLocation)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Current location status
          if (currentLocation != null) ...[
            Row(
              children: [
                Icon(
                  _isUsingDefaultLocation() ? Icons.location_city : Icons.location_on, 
                  color: _isUsingDefaultLocation() ? Colors.orange : Colors.green, 
                  size: 20
                ),
                const SizedBox(width: 8),
                Text(
                  _isUsingDefaultLocation() 
                      ? 'Using default Roxas City location'
                      : 'Current location obtained',
                  style: GoogleFonts.poppins(
                    color: _isUsingDefaultLocation() ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.location_off, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Location not available',
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Selected location indicator
          if (selectedLocation != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isSelectedLocationCurrentLocation() 
                    ? Colors.blue.withOpacity(0.2) 
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSelectedLocationCurrentLocation() ? Icons.my_location : Icons.place, 
                    color: _isSelectedLocationCurrentLocation() ? Colors.blue : Colors.orange, 
                    size: 20
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isSelectedLocationCurrentLocation() 
                          ? 'Using current location as incident location'
                          : 'Custom location selected',
                      style: GoogleFonts.poppins(
                        color: _isSelectedLocationCurrentLocation() ? Colors.blue : Colors.orange,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (!_isSelectedLocationCurrentLocation())
                    TextButton(
                      onPressed: _resetToCurrentLocation,
                      child: Text(
                        'Reset',
                        style: GoogleFonts.poppins(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Location coordinates
          if (locationToUse != null) ...[
            Text(
              'Lat: ${locationToUse.latitude!.toStringAsFixed(6)}\n'
              'Lng: ${locationToUse.longitude!.toStringAsFixed(6)}',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLoadingLocation ? null : () async {
                    await _getCurrentLocation();
                    // Ensure markers are updated if map is visible
                    if (showMapPicker && currentLocation != null) {
                      _initializeMarkersWithCurrentLocation();
                    }
                  },
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    isLoadingLocation ? 'Getting Location...' : 'Use Current',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      // Initialize markers when opening map for the first time
                      if (!showMapPicker && markers.isEmpty) {
                        _initializeMarkersWithCurrentLocation();
                      }
                      showMapPicker = !showMapPicker;
                    });
                  },
                  icon: const Icon(Icons.map),
                  label: Text(
                    showMapPicker ? 'Hide Map' : 'Pick Location',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: showMapPicker 
                        ? Colors.orange.withOpacity(0.8) 
                        : Colors.blue.withOpacity(0.8),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          // Map picker (can use default location if GPS not available)
          if (showMapPicker) ...[
            const SizedBox(height: 16),
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FutureBuilder<Widget>(
                  future: _buildMapWidget(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildMapFallback();
                    }
                    if (snapshot.hasData) {
                      return snapshot.data!;
                    }
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              selectedLocation != null && 
              selectedLocation!.latitude == currentLocation!.latitude &&
              selectedLocation!.longitude == currentLocation!.longitude
                  ? 'Red marker shows current incident location. Tap elsewhere to change (max ${(maxDistanceFromUser / 1000).toStringAsFixed(1)} km from your position)'
                  : 'Tap on the map to select incident location (max ${(maxDistanceFromUser / 1000).toStringAsFixed(1)} km from your position)',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Media (Optional)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: selectedMedia.length < 5 ? _showMediaPicker : null,
                icon: const Icon(Icons.add_a_photo, color: Colors.white),
              ),
            ],
          ),
          if (selectedMedia.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: selectedMedia.length,
                itemBuilder: (context, index) {
          final xfile = selectedMedia[index];
          final pathLower = xfile.path.toLowerCase();
          final nameLower = xfile.name.toLowerCase();
          final isVideo = pathLower.contains('.mp4') ||
              pathLower.contains('.mov') ||
              nameLower.contains('.mp4') ||
              nameLower.contains('.mov');
                  
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            isVideo ? Icons.videocam : Icons.image,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeMedia(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    size: 48,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add photos or videos to help describe the incident',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          if (selectedMedia.length >= 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Maximum 5 files allowed',
                style: GoogleFonts.poppins(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : _submitIncident,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Submit Incident Report',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}