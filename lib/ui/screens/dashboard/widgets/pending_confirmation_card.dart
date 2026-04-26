import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';

class PendingConfirmationCard extends StatelessWidget {
  final Map<String, dynamic> incident;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;
  final VoidCallback? onTap;

  const PendingConfirmationCard({
    Key? key,
    required this.incident,
    this.onConfirm,
    this.onReject,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final type = incident['incidentType'] ?? incident['type'] ?? 'Unknown';
    final description = incident['description'] ?? 'No description';
    final completionType = incident['completionType'] ?? 'completed';
    final resolutionNotes = incident['completionNotes'] ?? incident['resolutionNotes'] ?? '';
    final submittedAt = incident['submittedAt'] ?? incident['updatedAt'];
    final resolutionImages = incident['completionImages'] as List<dynamic>?
        ?? incident['resolutionImages'] as List<dynamic>?
        ?? [];
    final isFireOut = completionType == 'fire_out';

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
                color: Colors.amber.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: type badge + completion type badge + time
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
                              color: isFireOut
                                  ? Colors.deepOrange
                                  : Colors.green,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFireOut
                                      ? Icons.local_fire_department
                                      : Icons.check_circle,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isFireOut ? 'FIRE OUT' : 'COMPLETED',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatTime(submittedAt),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Resolution notes
                if (resolutionNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes, size: 16, color: Colors.white54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            resolutionNotes,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Proof photo thumbnails
                if (resolutionImages.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: resolutionImages.length,
                      itemBuilder: (context, index) {
                        return _buildPhotoThumbnail(context, resolutionImages[index]);
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Pending status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber, width: 1),
                  ),
                  child: Text(
                    'PENDING CONFIRMATION',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Action buttons: Confirm / Reject
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onConfirm,
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(
                          'Confirm',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(
                          'Reject',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
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
    );
  }

  Widget _buildPhotoThumbnail(BuildContext context, dynamic imageData) {
    if (imageData is! Map) return const SizedBox.shrink();

    final base64Data = imageData['dataBase64'] ?? imageData['data'];
    if (base64Data == null) return const SizedBox.shrink();

    try {
      final Uint8List bytes = base64Decode(base64Data);
      return GestureDetector(
        onTap: () => _showFullScreenImage(context, bytes, imageData['name'] ?? 'Proof Photo'),
        child: Container(
          width: 60,
          height: 60,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 24,
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
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
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
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

  String _formatTime(dynamic dateTimeData) {
    if (dateTimeData == null) return '';

    try {
      DateTime dateTime;

      if (dateTimeData is Map && dateTimeData['\$date'] != null) {
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
        return '';
      }

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
}
