import 'package:flutter/material.dart';
import 'package:fireout/services/auth_service.dart';
import 'package:fireout/ui/screens/dashboard/dashboard_screen.dart';
import 'package:fireout/ui/screens/user/user_dashboard_screen.dart';
import 'package:fireout/ui/screens/user/report_incident_screen.dart';
import 'package:fireout/ui/screens/user/user_incident_history_screen.dart';
import 'package:fireout/ui/screens/profile/profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleBasedMainScreen extends StatefulWidget {
  const RoleBasedMainScreen({Key? key}) : super(key: key);

  @override
  State<RoleBasedMainScreen> createState() => _RoleBasedMainScreenState();
}

class _RoleBasedMainScreenState extends State<RoleBasedMainScreen> {
  int _currentIndex = 0;
  String userRole = 'USER';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await AuthService().getUserRole();
    setState(() {
      userRole = role ?? 'USER';
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (userRole == 'USER') {
      return _buildUserNavigation();
    } else {
      return _buildOfficerNavigation();
    }
  }

  Widget _buildUserNavigation() {
    final screens = [
      const UserDashboardScreen(),
      const ReportIncidentScreen(),
      const UserIncidentHistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Theme.of(context).primaryColor,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report_problem),
            label: 'Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'My Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerNavigation() {
    return const DashboardScreen();
  }
}