import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
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

  @override
  void initState() {
    super.initState();
  }

  Future<void> _openDirections(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Unknown';
    
    try {
      final dateTime = DateTime.parse(dateTimeString);
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
    final caller = widget.incident['caller'];
    final callerName = caller?['fullName'] ?? caller?['username'] ?? 'Unknown';
    final callerPhone = caller?['phone'] ?? '';
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
                        _buildInfoRow('Name', callerName),
                        if (callerPhone.isNotEmpty) _buildInfoRow('Phone', callerPhone),
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
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
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
                            icon: const Icon(Icons.directions),
                            label: Text(
                              'Get Directions',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
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
                            onPressed: callerPhone.isNotEmpty 
                                ? () async {
                                    final url = 'tel:$callerPhone';
                                    final uri = Uri.parse(url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  }
                                : null,
                            icon: const Icon(Icons.phone),
                            label: Text(
                              'Call Reporter',
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
}