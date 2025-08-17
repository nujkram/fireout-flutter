import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:fireout/services/auth_service.dart';
import 'package:fireout/services/incident_service.dart';
import 'package:fireout/services/notification_service.dart';
import 'package:fireout/ui/screens/dashboard/widgets/incident_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final IncidentService _incidentService = IncidentService();
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> incidents = [];
  bool isLoading = true;
  String? userFullName;
  String? userRole;
  Timer? _refreshTimer;
  bool _isSilentRefreshing = false;
  // Track which incidents we've already notified about in this session
  final Set<String> _notifiedIncidentIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadIncidents();
    // Periodic silent refresh to keep incidents in sync with server
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _silentRefreshIncidents();
    });
  }

  Future<void> _loadUserData() async {
    final userData = await _authService.getCurrentUser();
    final role = await _authService.getUserRole();
    if (userData != null) {
      setState(() {
        userFullName = userData['fullName'] ?? userData['username'];
        userRole = role;
      });
    }
  }

  Future<void> _loadIncidents() async {
    setState(() {
      isLoading = true;
    });

    try {
      final fetchedIncidents = await _incidentService.getInProgressIncidents();
      setState(() {
        incidents = fetchedIncidents;
        isLoading = false;
      });
      // Trigger local notifications for any newly seen IN-PROGRESS incidents
      await _notifyNewInProgressIncidents(fetchedIncidents);
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading incidents: $e');
    }
  }

  Future<void> _refreshIncidents() async {
    await _loadIncidents();
  }

  Future<void> _silentRefreshIncidents() async {
    if (_isSilentRefreshing) return;
    _isSilentRefreshing = true;
    try {
      final fetchedIncidents = await _incidentService.getInProgressIncidents();
      if (!mounted) return;
      setState(() {
        incidents = fetchedIncidents;
      });
      // Trigger notifications for any new ones detected on refresh
      await _notifyNewInProgressIncidents(fetchedIncidents);
    } catch (_) {
      // Ignore errors during silent refresh to avoid UI disruption
    } finally {
      _isSilentRefreshing = false;
    }
  }

  Future<void> _notifyNewInProgressIncidents(List<Map<String, dynamic>> fetched) async {
    try {
      for (final incident in fetched) {
        final id = (incident['_id'] ?? '').toString();
        if (id.isEmpty) continue;
        if (_notifiedIncidentIds.contains(id)) continue;
        final status = (incident['status'] ?? '').toString();
        if (status == 'IN-PROGRESS') {
          final type = (incident['incidentType'] ?? 'General').toString();
          // Fire a local notification
          await _notificationService.handleIncidentStatusChange(id, status, type);
          _notifiedIncidentIds.add(id);
        }
      }
    } catch (e) {
      // Best-effort; do not surface to UI
      // ignore: avoid_print
      print('🚨 Error notifying for new in-progress incidents: $e');
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

      // Cancel the refresh timer to prevent issues
      _refreshTimer?.cancel();

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
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        title: Text(
          _getDashboardTitle(),
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
            onPressed: _refreshIncidents,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshIncidents,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, ${userFullName ?? _getDefaultRoleName()}!',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'In-Progress Incidents',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${incidents.length}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : incidents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: Colors.green[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No incidents in progress',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'All clear for now!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: incidents.length,
                            itemBuilder: (context, index) {
                              return IncidentCard(
                                incident: incidents[index],
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/incident-detail',
                                    arguments: incidents[index],
                                  ).then((_) => _silentRefreshIncidents());
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDashboardTitle() {
    switch (userRole) {
      case 'ADMINISTRATOR':
        return 'Admin Dashboard';
      case 'MANAGER':
        return 'Manager Dashboard';
      case 'OFFICER':
        return 'Officer Dashboard';
      default:
        return 'Emergency Dashboard';
    }
  }

  String _getDefaultRoleName() {
    switch (userRole) {
      case 'ADMINISTRATOR':
        return 'Administrator';
      case 'MANAGER':
        return 'Manager';
      case 'OFFICER':
        return 'Officer';
      default:
        return 'User';
    }
  }
}