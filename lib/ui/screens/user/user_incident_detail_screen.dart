import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:typed_data';

class UserIncidentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> incident;

  const UserIncidentDetailScreen({
    Key? key,
    required this.incident,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final incidentType = incident['incidentType'] ?? 'Unknown';
    final status = incident['status'] ?? 'UNKNOWN';
    final createdAt = incident['createdAt'];
    final updatedAt = incident['updatedAt'];
    final description = incident['description'] ?? '';
    final latitudeData = incident['latitude'] ?? incident['incidentLocation']?['latitude'];
    final longitudeData = incident['longitude'] ?? incident['incidentLocation']?['longitude'];
    final latitude = latitudeData is String ? double.tryParse(latitudeData) : latitudeData;
    final longitude = longitudeData is String ? double.tryParse(longitudeData) : longitudeData;
    final mediaFiles = incident['files'] ?? incident['media'] ?? [];

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
          if (latitude != null && longitude != null)
            IconButton(
              icon: const Icon(Icons.directions),
              onPressed: () => _openDirections(context, latitude, longitude),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(incidentType, status),
            const SizedBox(height: 16),
            if (description.isNotEmpty) ...[
              _buildDescriptionCard(description),
              const SizedBox(height: 16),
            ],
            _buildTimelineCard(createdAt, updatedAt),
            const SizedBox(height: 16),
            if (latitude != null && longitude != null) ...[
              _buildLocationCard(context, latitude, longitude),
              const SizedBox(height: 16),
            ],
            if (mediaFiles.isNotEmpty) ...[
              _buildMediaCard(mediaFiles),
              const SizedBox(height: 16),
            ],
            _buildStatusCard(status),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String incidentType, String status) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _getIncidentIcon(incidentType),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
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
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(String description) {
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
              const Icon(Icons.description, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'Description',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(String? createdAt, String? updatedAt) {
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
              const Icon(Icons.access_time, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'Timeline',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Reported', _formatDateTime(createdAt)),
          _buildInfoRow('Last Updated', _formatDateTime(updatedAt)),
        ],
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context, double latitude, double longitude) {
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
              const Icon(Icons.location_on, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'Location',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Latitude: ${latitude.toStringAsFixed(6)}\nLongitude: ${longitude.toStringAsFixed(6)}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openDirections(context, latitude, longitude),
            icon: const Icon(Icons.directions),
            label: const Text('Get Directions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCard(List mediaFiles) {
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
              const Icon(Icons.attach_file, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'Attached Files',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...mediaFiles.map<Widget>((media) {
            return _buildMediaItem(media);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMediaItem(Map<String, dynamic> media) {
    final filename = media['name'] ?? media['filename'] ?? 'Unknown file';
    final contentType = media['type'] ?? media['contentType'] ?? 'unknown';
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
      return _buildVideoPreview(bytes, filename);
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildImagePreview(Uint8List bytes, String filename) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => _showFullScreenImage(context, bytes, filename),
        child: Container(
          height: 200,
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

  Widget _buildVideoPreview(Uint8List bytes, String filename) {
    return Container(
      height: 200,
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
            size: 64,
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

  Widget _buildStatusCard(String status) {
    final statusInfo = _getStatusInfo(status);
    
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
              Icon(statusInfo['icon'], color: statusInfo['color'], size: 20),
              const SizedBox(width: 8),
              Text(
                'Current Status',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusInfo['description'],
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
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

  Widget _getIncidentIcon(String incidentType) {
    IconData iconData;
    Color iconColor;

    switch (incidentType.toLowerCase()) {
      case 'fire':
        iconData = Icons.local_fire_department;
        iconColor = Colors.red;
        break;
      case 'medical emergency':
      case 'medical':
        iconData = Icons.local_hospital;
        iconColor = Colors.blue;
        break;
      case 'traffic accident':
      case 'accident':
        iconData = Icons.car_crash;
        iconColor = Colors.orange;
        break;
      case 'crime':
        iconData = Icons.security;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.report_problem;
        iconColor = Colors.yellow;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 32,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'IN_PROGRESS':
      case 'IN-PROGRESS':
        return Colors.blue;
      case 'RESOLVED':
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'IN_PROGRESS':
      case 'IN-PROGRESS':
        return 'IN PROGRESS';
      default:
        return status.toUpperCase();
    }
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return {
          'icon': Icons.schedule,
          'color': Colors.orange,
          'description': 'Your incident report has been received and is waiting to be assigned to emergency responders.',
        };
      case 'IN_PROGRESS':
      case 'IN-PROGRESS':
        return {
          'icon': Icons.emergency,
          'color': Colors.blue,
          'description': 'Emergency responders have been assigned and are actively working on your incident.',
        };
      case 'RESOLVED':
      case 'COMPLETED':
        return {
          'icon': Icons.check_circle,
          'color': Colors.green,
          'description': 'Your incident has been successfully resolved. Thank you for reporting.',
        };
      case 'CANCELLED':
      case 'REJECTED':
        return {
          'icon': Icons.cancel,
          'color': Colors.red,
          'description': 'Your incident report was cancelled or could not be processed.',
        };
      default:
        return {
          'icon': Icons.help,
          'color': Colors.grey,
          'description': 'Status information is not available.',
        };
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

  Future<void> _openDirections(BuildContext context, double lat, double lng) async {
    // Try multiple methods to ensure compatibility across devices
    List<String> urls = [
      'google.navigation:q=$lat,$lng&mode=d', // Google Maps app navigation
      'geo:$lat,$lng?q=$lat,$lng', // Generic geo intent
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng', // Google Maps web URL
      'https://maps.google.com/?q=$lat,$lng', // Alternative Google Maps URL
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
    if (context.mounted) {
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
}