import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StationSelector extends StatelessWidget {
  final String? selectedStationId;
  final String? selectedStationName;
  final List<Map<String, dynamic>> availableStations;
  final Function(String?, String?) onStationChanged;

  const StationSelector({
    Key? key,
    required this.selectedStationId,
    required this.selectedStationName,
    required this.availableStations,
    required this.onStationChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assigned Station',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: selectedStationId,
            hint: Text(
              'Select a station',
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.location_city,
                color: Colors.white70,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            dropdownColor: Theme.of(context).primaryColor.withOpacity(0.95),
            items: availableStations.where((station) => station['isActive'] == true).map((Map<String, dynamic> station) {
              return DropdownMenuItem<String>(
                value: station['_id'],
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        station['name'] ?? 'Unknown Station',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (station['address'] != null)
                        Flexible(
                          child: Text(
                            station['address'],
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? stationId) {
              final selectedStation = availableStations.firstWhere(
                (station) => station['_id'] == stationId,
                orElse: () => {},
              );
              onStationChanged(stationId, selectedStation['name']);
            },
            icon: Icon(
              Icons.arrow_drop_down,
              color: Colors.white70,
            ),
          ),
        ),
        if (selectedStationName != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Currently assigned to:',
                        style: GoogleFonts.poppins(
                          color: Colors.blue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  selectedStationName!,
                  style: GoogleFonts.poppins(
                    color: Colors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (selectedStationId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Station ID: $selectedStationId',
                    style: GoogleFonts.poppins(
                      color: Colors.blue.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}