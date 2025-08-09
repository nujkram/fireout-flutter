import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class UserIncidentCard extends StatelessWidget {
  final Map<String, dynamic> incident;
  final VoidCallback onTap;

  const UserIncidentCard({
    Key? key,
    required this.incident,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = incident['status'] ?? 'PENDING';
    final incidentType = incident['incidentType'] ?? 'Unknown';
    final createdAt = incident['createdAt'];
    final hasMedia = incident['media'] != null && incident['media'].isNotEmpty;
    final description = incident['description'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _getIncidentIcon(incidentType),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              incidentType.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(createdAt),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    if (hasMedia) ...[
                      const SizedBox(width: 16),
                      Icon(
                        Icons.attach_file,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${incident['media'].length} file${incident['media'].length > 1 ? 's' : ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.white54,
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

    return Icon(
      iconData,
      color: iconColor,
      size: 24,
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

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateTime);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM dd, yyyy').format(date);
      }
    } catch (e) {
      return 'Invalid date';
    }
  }
}