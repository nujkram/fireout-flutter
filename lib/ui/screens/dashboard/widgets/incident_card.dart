import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class IncidentCard extends StatelessWidget {
  final Map<String, dynamic> incident;
  final VoidCallback? onTap;

  const IncidentCard({
    Key? key,
    required this.incident,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Handle both old mock data format and new API format
    final type = incident['incidentType'] ?? incident['type'] ?? 'Unknown';
    final description = incident['description'] ?? _generateDescription(type);
    final location = _getLocationString(incident);
    final priority = incident['priority'] ?? 'HIGH'; // Default to HIGH for active incidents
    final reportedAt = incident['createdAt'] ?? incident['reportedAt'];
    final emergencyLevel = incident['emergencyLevel'] ?? 'Critical';
    final reportedBy = _getReporterName(incident);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getPriorityColor(priority).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getTypeColor(type),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              type,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(priority),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              priority,
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
                    Text(
                      _formatTime(reportedAt),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (reportedBy.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Reported by: $reportedBy',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning,
                          size: 16,
                          color: _getPriorityColor(priority),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          emergencyLevel,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _getPriorityColor(priority),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'IN PROGRESS',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return Colors.red;
      case 'medical emergency':
      case 'medical':
        return Colors.blue;
      case 'accident':
        return Colors.orange;
      case 'natural disaster':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
      case 'CRITICAL':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(String? dateTimeString) {
    if (dateTimeString == null) return '';
    
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return DateFormat('MMM dd').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  String _getLocationString(Map<String, dynamic> incident) {
    // Try old format first
    if (incident['location'] != null && incident['location'] is String) {
      return incident['location'];
    }
    
    // Handle new API format with incidentLocation object
    final incidentLocation = incident['incidentLocation'];
    if (incidentLocation != null && incidentLocation is Map) {
      final lat = incidentLocation['latitude'];
      final lng = incidentLocation['longitude'];
      if (lat != null && lng != null) {
        return 'Lat: $lat, Lng: $lng';
      }
    }
    
    return 'Location not available';
  }

  String _getReporterName(Map<String, dynamic> incident) {
    // Try old format first
    if (incident['reportedBy'] != null) {
      return incident['reportedBy'].toString();
    }
    
    // Handle new API format with caller object
    final caller = incident['caller'];
    if (caller != null && caller is Map) {
      final fullName = caller['fullName'];
      final username = caller['username'];
      return fullName ?? username ?? 'Unknown';
    }
    
    return '';
  }

  String _generateDescription(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return 'Fire incident reported - immediate response required';
      case 'medical':
      case 'medical emergency':
        return 'Medical emergency - urgent medical assistance needed';
      case 'accident':
        return 'Accident reported - emergency response dispatched';
      default:
        return 'Emergency incident - response required';
    }
  }
}