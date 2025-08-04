import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fireout/services/auth_service.dart';
import 'package:fireout/services/incident_service.dart';
import 'package:fireout/ui/screens/dashboard/widgets/incident_card.dart';
import 'dart:convert';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final IncidentService _incidentService = IncidentService();
  List<Map<String, dynamic>> incidents = [];
  bool isLoading = true;
  String? userFullName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadIncidents();
  }

  Future<void> _loadUserData() async {
    final userData = await _authService.getCurrentUser();
    if (userData != null) {
      setState(() {
        userFullName = userData['fullName'] ?? userData['username'];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        title: Text(
          'Officer Dashboard',
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
            onPressed: () async {
              await _authService.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
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
                'Welcome back, ${userFullName ?? 'Officer'}!',
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
                                  // Navigate to incident details
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
}