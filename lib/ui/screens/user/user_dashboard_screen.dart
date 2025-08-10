import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fireout/services/auth_service.dart';
import 'package:fireout/services/user_incident_service.dart';
import 'package:fireout/services/station_service.dart';
import 'package:fireout/ui/screens/user/widgets/user_incident_card.dart';
import 'package:url_launcher/url_launcher.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({Key? key}) : super(key: key);

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  final AuthService _authService = AuthService();
  final UserIncidentService _incidentService = UserIncidentService();
  final StationService _stationService = StationService();
  List<Map<String, dynamic>> recentIncidents = [];
  List<Map<String, dynamic>> stations = [];
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);
    
    try {
      userData = await _authService.getCurrentUser();
      
      final incidents = await _incidentService.getUserIncidents();
      recentIncidents = incidents.take(5).toList();
      
      stations = await _stationService.getStations();
      print('📋 Dashboard loaded ${stations.length} stations');
      
      // Temporary fallback if no stations loaded
      if (stations.isEmpty) {
        print('⚠️ No stations from backend, using temporary fallback');
        stations = [
          {
            '_id': 'temp_1',
            'name': 'Roxas City Fire Department',
            'type': 'Fire Department',
            'address': 'Bilbao Street, Roxas City, Capiz',
            'phone': '09171234567',
            'emergencyNumber': '911',
          },
          {
            '_id': 'temp_2', 
            'name': 'Roxas City Lawa-an Sub Station',
            'type': 'Emergency Station',
            'address': 'Pueblo de Panay, Roxas City, Capiz',
            'phone': '639171234568',
            'emergencyNumber': '911',
          }
        ];
      }
      
      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      print('Error loading dashboard data: $e');
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Logout',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: GoogleFonts.poppins(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout();
              },
              child: Text(
                'Logout',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.red),
                const SizedBox(width: 16),
                Text(
                  'Logging out...',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ],
            ),
          );
        },
      );

      // Perform logout
      await _authService.logout();
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      // Navigate to login screen and clear the navigation stack
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();
      
      print('Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'An error occurred during logout.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        title: Text(
          'Emergency Services',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildRecentIncidents(),
                    const SizedBox(height: 24),
                    _buildStations(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeSection() {
    final name = userData?['fullName'] ?? userData?['username'] ?? 'Citizen';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $name',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Report emergencies and track your incident reports',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.report_problem,
                title: 'Report Emergency',
                subtitle: 'Report incident with location',
                color: Colors.red,
                onTap: () => Navigator.pushNamed(context, '/report-incident'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.history,
                title: 'Track Reports',
                subtitle: 'View your incident history',
                color: Colors.blue,
                onTap: () => Navigator.pushNamed(context, '/user-incident-history'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 120,
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
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentIncidents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Reports',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (recentIncidents.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/user-incident-history'),
                child: Text(
                  'View All',
                  style: GoogleFonts.poppins(color: Colors.white70),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (recentIncidents.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.report_outlined,
                    size: 48,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No recent reports',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...recentIncidents.map((incident) => UserIncidentCard(
                incident: incident,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/user-incident-detail',
                  arguments: incident,
                ),
              )),
      ],
    );
  }

  Widget _buildStations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency Stations',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (stations.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.local_fire_department_outlined,
                    size: 48,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No stations available',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: stations.asMap().entries.map((entry) {
                final index = entry.key;
                final station = entry.value;
                return Column(
                  children: [
                    if (index > 0) const Divider(color: Colors.white24),
                    _buildStationContact(station),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildStationContact(Map<String, dynamic> station) {
    IconData icon;
    Color iconColor = Colors.red;

    switch (station['type']?.toString().toLowerCase()) {
      case 'fire department':
        icon = Icons.local_fire_department;
        iconColor = Colors.red;
        break;
      case 'police':
        icon = Icons.local_police;
        iconColor = Colors.blue;
        break;
      case 'medical emergency':
        icon = Icons.local_hospital;
        iconColor = Colors.green;
        break;
      default:
        icon = Icons.emergency;
        iconColor = Colors.orange;
    }

    final emergencyNumber = station['emergencyNumber']?.toString() ?? '911';
    final stationName = station['name']?.toString() ?? 'Unknown Station';
    final stationAddress = station['address']?.toString() ?? '';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        stationName,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: stationAddress.isNotEmpty
          ? Text(
              stationAddress,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
              ),
            )
          : null,
      trailing: TextButton(
        onPressed: () async {
          final url = 'tel:$emergencyNumber';
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
        child: Text(
          'Call',
          style: GoogleFonts.poppins(
            color: iconColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}