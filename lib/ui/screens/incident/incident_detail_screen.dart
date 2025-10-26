import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import 'package:fireout/services/auth_service.dart';
import 'package:fireout/services/incident_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

class IncidentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> incident;

  const IncidentDetailScreen({
    Key? key,
    required this.incident,
  }) : super(key: key);

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  bool _isLoadingLocation = false;
  Position? _currentPosition;
  String? _userRole;
  Map<String, dynamic>? _reporterData;
  bool _isLoadingReporter = false;
  final AuthService _authService = AuthService();
  final IncidentService _incidentService = IncidentService();

  // Resolution state
  final List<XFile> _resolutionImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isResolvingIncident = false;
  final TextEditingController _resolutionNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadUserRole();
    _loadReporterData();
  }

  Future<void> _loadUserRole() async {
    final role = await _authService.getUserRole();
    setState(() {
      _userRole = role;
    });
  }

  Future<void> _loadReporterData() async {
    final userId = widget.incident['userId'];
    if (userId == null) return;

    setState(() => _isLoadingReporter = true);
    
    try {
      final userData = await _incidentService.getUserById(userId);
      setState(() {
        _reporterData = userData;
        _isLoadingReporter = false;
      });
    } catch (e) {
      setState(() => _isLoadingReporter = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reporter information: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      final status = await permission_handler.Permission.location.request();
      if (status != permission_handler.PermissionStatus.granted) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get current location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openDirections(double lat, double lng) async {
    // Try multiple methods to ensure compatibility across devices
    List<String> urls = [];
    
    if (_currentPosition != null) {
      // Method 1: Google Maps app with current location as starting point
      urls.add('google.navigation:q=$lat,$lng&mode=d');
      // Method 2: Generic maps intent
      urls.add('geo:${_currentPosition!.latitude},${_currentPosition!.longitude}?q=$lat,$lng');
      // Method 3: Web URL with current location
      urls.add('https://www.google.com/maps/dir/${_currentPosition!.latitude},${_currentPosition!.longitude}/$lat,$lng');
    } else {
      // Method 1: Google Maps app without starting point
      urls.add('google.navigation:q=$lat,$lng&mode=d');
      // Method 2: Generic maps intent
      urls.add('geo:$lat,$lng?q=$lat,$lng');
      // Method 3: Web URL without starting point
      urls.add('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    }
    
    // Try each URL until one works
    for (String url in urls) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return; // Success, exit the method
        }
      } catch (e) {
        print('Failed to launch $url: $e');
        continue; // Try next URL
      }
    }
    
    // If all methods fail, show error message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open directions. Please check if you have a maps app installed.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    // Try multiple methods to ensure compatibility across devices
    List<String> urls = [
      'geo:$lat,$lng?q=$lat,$lng', // Generic geo intent
      'https://maps.google.com/?q=$lat,$lng', // Google Maps web URL
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng', // Google Maps API URL
    ];
    
    // Try each URL until one works
    for (String url in urls) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return; // Success, exit the method
        }
      } catch (e) {
        print('Failed to launch $url: $e');
        continue; // Try next URL
      }
    }
    
    // If all methods fail, show error message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open maps. Please check if you have a maps app installed.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getIncidentTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return '🔥';
      case 'medical':
      case 'medical emergency':
        return '🚑';
      case 'accident':
        return '🚗';
      default:
        return '🚨';
    }
  }

  Color _getIncidentTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return Colors.red;
      case 'medical':
      case 'medical emergency':
        return Colors.blue;
      case 'accident':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(dynamic dateTimeData) {
    if (dateTimeData == null) return 'Unknown';
    
    try {
      DateTime dateTime;
      
      if (dateTimeData is Map && dateTimeData['\$date'] != null) {
        // Handle MongoDB date format: {$date: {$numberLong: "timestamp"}}
        final dateMap = dateTimeData['\$date'];
        if (dateMap is Map && dateMap['\$numberLong'] != null) {
          final timestamp = int.parse(dateMap['\$numberLong'].toString());
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else {
          dateTime = DateTime.parse(dateMap.toString());
        }
      } else if (dateTimeData is String) {
        dateTime = DateTime.parse(dateTimeData);
      } else {
        return 'Invalid date format';
      }
      
      return DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildMapSection() {
    final incidentLocation = widget.incident['incidentLocation'];
    if (incidentLocation == null) {
      return Container(
        height: 300,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Location not available'),
        ),
      );
    }

    final lat = double.tryParse(incidentLocation['latitude'].toString());
    final lng = double.tryParse(incidentLocation['longitude'].toString());

    if (lat == null || lng == null) {
      return Container(
        height: 300,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Invalid location coordinates'),
        ),
      );
    }

    // Use Google Static Maps API for cross-platform compatibility
    final staticMapUrl = 'https://maps.googleapis.com/maps/api/staticmap?'
        'center=$lat,$lng&'
        'zoom=15&'
        'size=600x300&'
        'maptype=roadmap&'
        'markers=color:red%7C$lat,$lng&'
        'key=AIzaSyAfF1xS4lG6Wi_R2WdydtWSEaiDNV1f2bg';

    return Container(
      height: 300,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Static map image
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey[300],
              child: Image.network(
                staticMapUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.map, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'Map Preview',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lat: ${lat.toStringAsFixed(6)}',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Lng: ${lng.toStringAsFixed(6)}',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Overlay buttons
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    onPressed: () => _openInMaps(lat, lng),
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.map, color: Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    onPressed: () => _openDirections(lat, lng),
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.directions, color: Colors.green),
                  ),
                ],
              ),
            ),
            // Location marker overlay
            const Positioned(
              top: 50,
              left: 20,
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.red, size: 24),
                  SizedBox(width: 4),
                  Text(
                    'Incident Location',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incidentType = widget.incident['incidentType'] ?? 'Unknown';
    final callerName = _reporterData?['fullName'] ?? _reporterData?['username'] ?? 'Loading...';
    final callerPhone = _reporterData?['phone'] ?? '';
    final status = widget.incident['status'] ?? 'UNKNOWN';
    final createdAt = widget.incident['createdAt'];
    final updatedAt = widget.incident['updatedAt'];

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        title: Text(
          'Incident Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions),
            onPressed: () {
              final incidentLocation = widget.incident['incidentLocation'];
              if (incidentLocation != null) {
                final lat = double.tryParse(incidentLocation['latitude'].toString());
                final lng = double.tryParse(incidentLocation['longitude'].toString());
                if (lat != null && lng != null) {
                  _openDirections(lat, lng);
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Map Section
          _buildMapSection(),

          // Incident Details Section
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with incident type and status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              _getIncidentTypeIcon(incidentType),
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  incidentType.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Emergency Incident',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: status == 'IN-PROGRESS' ? Colors.orange : Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.replaceAll('-', ' '),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Caller Information
                    _buildInfoSection(
                      'Reported By',
                      Icons.person,
                      [
                        if (_isLoadingReporter)
                          Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Loading reporter information...',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _buildInfoRow('Name', callerName),
                          if (callerPhone.isNotEmpty) _buildInfoRow('Phone', callerPhone),
                          if (_reporterData?['email'] != null) _buildInfoRow('Email', _reporterData!['email']),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Time Information
                    _buildInfoSection(
                      'Timeline',
                      Icons.access_time,
                      [
                        _buildInfoRow('Reported', _formatDateTime(createdAt)),
                        _buildInfoRow('Last Updated', _formatDateTime(updatedAt)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Location Information
                    _buildInfoSection(
                      'Location',
                      Icons.location_on,
                      [
                        _buildInfoRow('Coordinates', 
                          '${widget.incident['incidentLocation']?['latitude']}, ${widget.incident['incidentLocation']?['longitude']}'),
                        if (_currentPosition != null)
                          _buildInfoRow('Distance', _calculateDistance()),
                      ],
                    ),

                    // Media Files Section
                    if (widget.incident['files'] != null && (widget.incident['files'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildMediaSection(),
                    ],

                    const SizedBox(height: 24),

                    // Current Location Status
                    if (_isLoadingLocation)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Getting your current location...',
                              style: GoogleFonts.poppins(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Action Buttons
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _currentPosition == null ? null : () {
                                  final incidentLocation = widget.incident['incidentLocation'];
                                  if (incidentLocation != null) {
                                    final lat = double.tryParse(incidentLocation['latitude'].toString());
                                    final lng = double.tryParse(incidentLocation['longitude'].toString());
                                    if (lat != null && lng != null) {
                                      _openDirections(lat, lng);
                                    }
                                  }
                                },
                                icon: Icon(_currentPosition != null ? Icons.directions : Icons.location_searching),
                                label: Text(
                                  _currentPosition != null ? 'Get Directions' : 'Getting Location...',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentPosition != null ? Colors.blue : Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (!_isLoadingReporter && callerPhone.isNotEmpty) 
                                    ? () async {
                                        final url = 'tel:$callerPhone';
                                        final uri = Uri.parse(url);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri);
                                        }
                                      }
                                    : null,
                                icon: _isLoadingReporter 
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.phone),
                                label: Text(
                                  _isLoadingReporter 
                                      ? 'Loading...'
                                      : callerPhone.isNotEmpty 
                                          ? 'Call Reporter'
                                          : 'No Phone Available',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (!_isLoadingReporter && callerPhone.isNotEmpty) 
                                      ? Colors.green 
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (widget.incident['status'] == 'IN-PROGRESS' && _canUpdateStatus())
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showStatusUpdateDialog(),
                              icon: const Icon(Icons.check_circle),
                              label: Text(
                                'Mark as Completed',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
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
              Icon(icon, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateDistance() {
    if (_currentPosition == null) return 'Unknown';
    
    final incidentLocation = widget.incident['incidentLocation'];
    if (incidentLocation == null) return 'Unknown';
    
    final lat = double.tryParse(incidentLocation['latitude']?.toString() ?? '');
    final lng = double.tryParse(incidentLocation['longitude']?.toString() ?? '');
    
    if (lat == null || lng == null) return 'Unknown';
    
    final distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
    
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(2)} km';
    }
  }

  Widget _buildMediaSection() {
    final mediaFiles = widget.incident['files'] as List<dynamic>;
    
    return _buildInfoSection(
      'Attached Files',
      Icons.attach_file,
      [
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: mediaFiles.length,
            itemBuilder: (context, index) {
              return _buildMediaItem(mediaFiles[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItem(Map<String, dynamic> media) {
    final filename = media['name'] ?? 'Unknown file';
    final contentType = media['type'] ?? 'unknown';
    final base64Data = media['data'];
    final sizeData = media['size'];
    final size = sizeData is Map ? sizeData['\$numberInt'] != null ? int.tryParse(sizeData['\$numberInt'].toString()) : sizeData['value'] : sizeData;
    
    // Display file info
    final fileInfo = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getFileIcon(contentType),
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              filename,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
          if (size != null)
            Text(
              '${(size / 1024).toStringAsFixed(1)} KB',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.white54,
              ),
            ),
        ],
      ),
    );

    if (base64Data == null) {
      return fileInfo;
    }

    try {
      final bytes = base64Decode(base64Data);
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fileInfo,
          const SizedBox(height: 8),
          _buildMediaPreview(bytes, contentType, filename),
          const SizedBox(height: 12),
        ],
      );
    } catch (e) {
      return fileInfo;
    }
  }

  Widget _buildMediaPreview(Uint8List bytes, String contentType, String filename) {
    if (contentType.startsWith('image/')) {
      return _buildImagePreview(bytes, filename);
    } else if (contentType.startsWith('video/')) {
      return _buildVideoPreview(filename);
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildImagePreview(Uint8List bytes, String filename) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => _showFullScreenImage(context, bytes, filename),
        child: Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.white.withOpacity(0.1),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPreview(String filename) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.play_circle_outline,
            color: Colors.white70,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            'Video File',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to view details',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, Uint8List bytes, String filename) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              filename,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String contentType) {
    if (contentType.startsWith('image/')) {
      return Icons.image;
    } else if (contentType.startsWith('video/')) {
      return Icons.videocam;
    } else {
      return Icons.attach_file;
    }
  }

  bool _canUpdateStatus() {
    return _userRole == 'ADMINISTRATOR' || _userRole == 'MANAGER' || _userRole == 'OFFICER';
  }

  void _showStatusUpdateDialog() {
    _resolutionImages.clear();
    _resolutionNotesController.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Complete Incident',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add resolution details and photos:',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Resolution Notes
                  TextField(
                    controller: _resolutionNotesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Resolution Notes',
                      hintText: 'Describe how the incident was resolved...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelStyle: GoogleFonts.poppins(),
                      hintStyle: GoogleFonts.poppins(fontSize: 12),
                    ),
                    style: GoogleFonts.poppins(),
                  ),

                  const SizedBox(height: 16),

                  // Image Capture Section
                  Text(
                    'Resolution Photos (Optional)',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Image Picker Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resolutionImages.length >= 5
                              ? null
                              : () async {
                                  await _pickResolutionImage(ImageSource.camera);
                                  setState(() {});
                                },
                          icon: const Icon(Icons.camera_alt, size: 20),
                          label: Text(
                            'Camera',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resolutionImages.length >= 5
                              ? null
                              : () async {
                                  await _pickResolutionImage(ImageSource.gallery);
                                  setState(() {});
                                },
                          icon: const Icon(Icons.photo_library, size: 20),
                          label: Text(
                            'Gallery',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_resolutionImages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${_resolutionImages.length}/5 photos',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),

                    // Image Preview Grid
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _resolutionImages.length,
                        itemBuilder: (context, index) {
                          return _buildImagePreviewItem(
                            _resolutionImages[index],
                            index,
                            setState,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _resolutionImages.clear();
                _resolutionNotesController.clear();
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isResolvingIncident
                  ? null
                  : () async {
                      if (_resolutionNotesController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please add resolution notes',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context);
                      await _updateIncidentStatus();
                    },
              icon: _isResolvingIncident
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _isResolvingIncident ? 'Completing...' : 'Complete Incident',
                style: GoogleFonts.poppins(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviewItem(XFile image, int index, StateSetter setState) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: kIsWeb
                ? Image.network(
                    image.path,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    File(image.path),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _resolutionImages.removeAt(index);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
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
  }

  Future<void> _pickResolutionImage(ImageSource source) async {
    try {
      // Request camera permission if using camera
      if (source == ImageSource.camera) {
        final status = await permission_handler.Permission.camera.request();
        if (status != permission_handler.PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Camera permission is required',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        if (_resolutionImages.length < 5) {
          _resolutionImages.add(image);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Maximum 5 photos allowed',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pick image: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateIncidentStatus() async {
    setState(() {
      _isResolvingIncident = true;
    });

    try {
      // Convert images to base64
      List<Map<String, dynamic>> resolutionImageData = [];
      for (var image in _resolutionImages) {
        try {
          final bytes = await image.readAsBytes();
          final base64Image = base64Encode(bytes);
          final fileName = image.name;
          final fileSize = bytes.length;

          resolutionImageData.add({
            'name': fileName,
            'type': _getContentType(fileName),
            'dataBase64': base64Image,
            'size': fileSize,
          });
        } catch (e) {
          print('Error encoding image: $e');
        }
      }

      final incidentId = widget.incident['_id'];
      if (incidentId == null) {
        throw Exception('Incident ID not found');
      }

      // Call the incident service to resolve the incident
      final success = await _incidentService.resolveIncident(
        incidentId,
        resolutionNotes: _resolutionNotesController.text.trim(),
        resolutionImages: resolutionImageData,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Incident marked as completed successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back to dashboard
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update incident status',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error updating incident status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update status: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingIncident = false;
        });
      }
      _resolutionImages.clear();
      _resolutionNotesController.clear();
    }
  }

  String _getContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }
}