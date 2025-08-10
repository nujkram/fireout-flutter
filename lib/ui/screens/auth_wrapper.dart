import 'package:flutter/material.dart';
import 'package:fireout/services/auth_service.dart';
import 'package:fireout/ui/screens/login/login_screen.dart';
import 'package:fireout/ui/screens/role_based_main_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      print('🔐 Checking authentication status...');
      
      // First ensure auth is initialized (loads token from SharedPreferences)
      await _authService.initializeAuth();
      
      // Check if user has a stored auth token
      final isAuthenticated = _authService.isAuthenticated;
      print('🔐 Has auth token: $isAuthenticated');
      
      if (isAuthenticated) {
        // Verify the token is still valid by trying to get user data
        final userData = await _authService.getCurrentUser();
        print('🔐 User data retrieved: ${userData != null}');
        
        if (userData != null) {
          final role = await _authService.getUserRole();
          print('🔐 User role: $role');
        }
        
        setState(() {
          _isAuthenticated = userData != null;
          _isLoading = false;
        });
      } else {
        print('🔐 No auth token found');
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('🚨 Error checking authentication: $e');
      // If there's an error, assume not authenticated
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Show loading screen while checking authentication
      return Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Navigate based on authentication status
    if (_isAuthenticated) {
      print('🔐 User is authenticated, showing main screen');
      return const RoleBasedMainScreen();
    } else {
      print('🔐 User is not authenticated, showing login screen');
      return const LoginScreen();
    }
  }
}