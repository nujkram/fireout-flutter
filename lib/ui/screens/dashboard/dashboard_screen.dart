import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:fireout/services/auth_service.dart';
import 'package:fireout/services/incident_service.dart';
import 'package:fireout/services/notification_service.dart';
import 'package:fireout/services/station_service.dart';
import 'package:fireout/ui/screens/dashboard/widgets/incident_card.dart';
import 'package:fireout/ui/screens/dashboard/widgets/pending_confirmation_card.dart';
import 'package:fireout/utils/geolocation_utils.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final IncidentService _incidentService = IncidentService();
  final NotificationService _notificationService = NotificationService();
  final StationService _stationService = StationService();
  List<Map<String, dynamic>> incidents = [];
  List<Map<String, dynamic>> pendingIncidents = [];
  bool isLoading = true;
  bool isPendingLoading = false;
  String? userFullName;
  String? userRole;
  Map<String, dynamic>? _userStation;
  Timer? _refreshTimer;
  bool _isSilentRefreshing = false;
  int _selectedTab = 0; // 0 = In-Progress, 1 = Pending Confirmation
  // Track which incidents we've already notified about in this session
  final Set<String> _notifiedIncidentIds = <String>{};
  final TextEditingController _rejectionReasonController = TextEditingController();

  bool get _canViewPendingTab =>
      userRole == 'ADMINISTRATOR' || userRole == 'MANAGER';

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
      // Load pending incidents for admins/managers
      if (role == 'ADMINISTRATOR' || role == 'MANAGER') {
        _loadPendingIncidents();
      }
    }
    await _loadUserStation();
  }

  Future<void> _loadUserStation() async {
    try {
      final stationId = await _authService.getStationId();
      if (stationId == null || stationId.isEmpty) return;
      final station = await _stationService.getStationById(stationId);
      if (!mounted) return;
      setState(() {
        _userStation = station;
        // Re-apply filter to anything already fetched
        if (incidents.isNotEmpty) {
          incidents = _applyProximityFilter(incidents);
        }
      });
    } catch (e) {
      print('Error loading user station: $e');
    }
  }

  List<Map<String, dynamic>> _applyProximityFilter(
    List<Map<String, dynamic>> rawIncidents,
  ) {
    // Administrators see every incident.
    if (userRole == 'ADMINISTRATOR') return rawIncidents;
    // Officers/Managers without an assigned station fall back to seeing all.
    if (userRole != 'OFFICER' && userRole != 'MANAGER') return rawIncidents;
    final station = _userStation;
    if (station == null) return rawIncidents;

    final lat = _toDouble(station['latitude']);
    final lng = _toDouble(station['longitude']);
    if (lat == null || lng == null) return rawIncidents;

    final radius = _toDouble(station['coverageRadius']) ?? 7.0;
    return filterIncidentsByProximity(rawIncidents, lat, lng, radius);
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<void> _loadPendingIncidents() async {
    setState(() => isPendingLoading = true);
    try {
      final fetched = await _incidentService.getPendingCompletionIncidents();
      if (mounted) {
        setState(() {
          pendingIncidents = fetched;
          isPendingLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isPendingLoading = false);
      }
      print('Error loading pending incidents: $e');
    }
  }

  Future<void> _loadIncidents() async {
    setState(() {
      isLoading = true;
    });

    try {
      final fetchedIncidents = await _incidentService.getInProgressIncidents();
      final filtered = _applyProximityFilter(fetchedIncidents);
      setState(() {
        incidents = filtered;
        isLoading = false;
      });
      // Trigger local notifications for any newly seen IN-PROGRESS incidents
      await _notifyNewInProgressIncidents(filtered);
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
      final filtered = _applyProximityFilter(fetchedIncidents);
      setState(() {
        incidents = filtered;
      });
      // Trigger notifications for any new ones detected on refresh
      await _notifyNewInProgressIncidents(filtered);

      // Also refresh pending incidents for admins/managers
      if (_canViewPendingTab) {
        try {
          final fetchedPending = await _incidentService.getPendingCompletionIncidents();
          if (mounted) {
            setState(() {
              pendingIncidents = fetchedPending;
            });
          }
        } catch (_) {}
      }
    } catch (_) {
      // Ignore errors during silent refresh to avoid UI disruption
    } finally {
      _isSilentRefreshing = false;
    }
  }

  Future<void> _notifyNewInProgressIncidents(List<Map<String, dynamic>> fetched) async {
    for (final incident in fetched) {
      try {
        final id = (incident['_id'] ?? '').toString();
        if (id.isEmpty) continue;
        if (_notifiedIncidentIds.contains(id)) continue;
        final status = (incident['status'] ?? '').toString();
        if (status != 'IN-PROGRESS') continue;
        final type = (incident['incidentType'] ?? 'General').toString();
        await _notificationService.handleIncidentStatusChange(id, status, type);
        _notifiedIncidentIds.add(id);
      } catch (e) {
        // ignore: avoid_print
        print('🚨 notify error for one incident: $e');
      }
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

  Future<void> _handleConfirm(Map<String, dynamic> incident) async {
    final incidentId = incident['_id']?.toString();
    if (incidentId == null) return;

    final completionType = incident['completionType'] ?? 'completed';
    final label = completionType == 'fire_out' ? 'fire out declaration' : 'completion';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm $label?',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will officially close the incident and mark it as completed.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Confirm', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(width: 16),
              Text('Confirming...', style: GoogleFonts.poppins(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    final success = await _incidentService.confirmCompletion(incidentId);

    if (mounted) Navigator.pop(context); // close loading

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Incident confirmed as completed' : 'Failed to confirm incident',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) {
        _loadPendingIncidents();
        _silentRefreshIncidents();
      }
    }
  }

  Future<void> _handleReject(Map<String, dynamic> incident) async {
    final incidentId = incident['_id']?.toString();
    if (incidentId == null) return;

    _rejectionReasonController.clear();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reject Completion',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The incident will return to IN-PROGRESS status. Please provide a reason:',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectionReasonController,
              maxLines: 3,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Reason for rejection...',
                hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _rejectionReasonController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please provide a rejection reason', style: GoogleFonts.poppins()),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Reject', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.red),
              const SizedBox(width: 16),
              Text('Rejecting...', style: GoogleFonts.poppins(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    final success = await _incidentService.rejectCompletion(incidentId, reason);

    if (mounted) Navigator.pop(context); // close loading

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Completion rejected. Incident returned to IN-PROGRESS.' : 'Failed to reject completion',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
      if (success) {
        _loadPendingIncidents();
        _silentRefreshIncidents();
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _rejectionReasonController.dispose();
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
            onPressed: () {
              _refreshIncidents();
              if (_canViewPendingTab) _loadPendingIncidents();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshIncidents();
          if (_canViewPendingTab) await _loadPendingIncidents();
        },
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
              const SizedBox(height: 16),

              // Tab switcher for admins/managers
              if (_canViewPendingTab) ...[
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? Colors.orange
                                : Colors.white.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              bottomLeft: Radius.circular(10),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'In-Progress',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: _selectedTab == 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${incidents.length}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? Colors.amber
                                : Colors.white.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Pending',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: _selectedTab == 1
                                      ? Colors.black87
                                      : Colors.white,
                                  fontWeight: _selectedTab == 1
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 1
                                      ? Colors.black.withOpacity(0.15)
                                      : Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${pendingIncidents.length}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: _selectedTab == 1
                                        ? Colors.black87
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Section header for officers (no tabs)
              if (!_canViewPendingTab) ...[
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
              ],

              // Content area
              Expanded(
                child: _selectedTab == 0 || !_canViewPendingTab
                    ? _buildInProgressList()
                    : _buildPendingConfirmationList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInProgressList() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (incidents.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
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
    );
  }

  Widget _buildPendingConfirmationList() {
    if (isPendingLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }

    if (pendingIncidents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pending_actions,
              size: 64,
              color: Colors.amber[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No pending confirmations',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All submissions have been reviewed.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: pendingIncidents.length,
      itemBuilder: (context, index) {
        final incident = pendingIncidents[index];
        return PendingConfirmationCard(
          incident: incident,
          onConfirm: () => _handleConfirm(incident),
          onReject: () => _handleReject(incident),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/incident-detail',
              arguments: incident,
            ).then((_) {
              _silentRefreshIncidents();
              _loadPendingIncidents();
            });
          },
        );
      },
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