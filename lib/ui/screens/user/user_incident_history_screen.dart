import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fireout/services/user_incident_service.dart';
import 'package:fireout/ui/screens/user/widgets/user_incident_card.dart';

class UserIncidentHistoryScreen extends StatefulWidget {
  const UserIncidentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<UserIncidentHistoryScreen> createState() => _UserIncidentHistoryScreenState();
}

class _UserIncidentHistoryScreenState extends State<UserIncidentHistoryScreen> {
  final UserIncidentService _incidentService = UserIncidentService();
  List<Map<String, dynamic>> userIncidents = [];
  List<Map<String, dynamic>> filteredIncidents = [];
  bool isLoading = true;
  String selectedFilter = 'ALL';

  final List<String> filterOptions = ['ALL', 'PENDING', 'IN_PROGRESS', 'RESOLVED'];

  @override
  void initState() {
    super.initState();
    _loadUserIncidents();
  }

  Future<void> _loadUserIncidents() async {
    setState(() => isLoading = true);
    
    try {
      final incidents = await _incidentService.getUserIncidents();
      setState(() {
        userIncidents = incidents;
        _applyFilter();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load incidents: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _applyFilter() {
    if (selectedFilter == 'ALL') {
      filteredIncidents = List.from(userIncidents);
    } else {
      filteredIncidents = userIncidents
          .where((incident) => _mapStatusToFilter(incident['status']) == selectedFilter)
          .toList();
    }
  }

  String _mapStatusToFilter(String? status) {
    if (status == null) return 'UNKNOWN';
    
    final upperStatus = status.toUpperCase();
    switch (upperStatus) {
      case 'PENDING':
        return 'PENDING';
      case 'IN PROGRESS':
      case 'IN_PROGRESS':
      case 'IN-PROGRESS':
        return 'IN_PROGRESS';
      case 'COMPLETED':
      case 'RESOLVED':
      case 'CLOSED':
        return 'RESOLVED';
      default:
        return 'UNKNOWN';
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      selectedFilter = filter;
      _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        title: Text(
          'My Incident Reports',
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
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadUserIncidents,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : RefreshIndicator(
                    onRefresh: _loadUserIncidents,
                    child: _buildIncidentsList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/report-incident');
          if (result == true) {
            _loadUserIncidents();
          }
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by Status',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filterOptions.map((filter) {
                final isSelected = selectedFilter == filter;
                final count = filter == 'ALL' 
                    ? userIncidents.length 
                    : userIncidents.where((i) => _mapStatusToFilter(i['status']) == filter).length;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _onFilterChanged(filter),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getFilterDisplayName(filter),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getFilterColor(filter),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              count.toString(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentsList() {
    if (filteredIncidents.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredIncidents.length,
      itemBuilder: (context, index) {
        final incident = filteredIncidents[index];
        return UserIncidentCard(
          incident: incident,
          onTap: () => _viewIncidentDetails(incident),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    
    if (userIncidents.isEmpty) {
      message = 'No incidents reported yet.\nTap the + button to report your first incident.';
      icon = Icons.report_outlined;
    } else {
      message = 'No ${_getFilterDisplayName(selectedFilter).toLowerCase()} incidents found.';
      icon = Icons.filter_list_off;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            if (userIncidents.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.pushNamed(context, '/report-incident');
                  if (result == true) {
                    _loadUserIncidents();
                  }
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Report Incident'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _viewIncidentDetails(Map<String, dynamic> incident) {
    Navigator.pushNamed(
      context,
      '/user-incident-detail',
      arguments: incident,
    );
  }

  String _getFilterDisplayName(String filter) {
    switch (filter) {
      case 'ALL':
        return 'All';
      case 'PENDING':
        return 'Pending';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'RESOLVED':
        return 'Resolved';
      default:
        return filter;
    }
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'ALL':
        return Colors.blue.withOpacity(0.8);
      case 'PENDING':
        return Colors.orange.withOpacity(0.8);
      case 'IN_PROGRESS':
        return Colors.blue.withOpacity(0.8);
      case 'RESOLVED':
        return Colors.green.withOpacity(0.8);
      default:
        return Colors.grey.withOpacity(0.8);
    }
  }
}