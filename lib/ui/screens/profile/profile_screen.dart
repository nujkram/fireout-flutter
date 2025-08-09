import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fireout/services/auth_service.dart';
import 'package:fireout/services/profile_service.dart';
import 'package:fireout/ui/screens/profile/widgets/profile_field.dart';
import 'package:fireout/ui/screens/profile/widgets/station_selector.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  Map<String, dynamic>? userData;
  String? selectedStationId;
  String? selectedStationName;
  List<Map<String, dynamic>> availableStations = [];
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStations();
  }

  Future<void> _loadUserData() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      setState(() {
        userData = user;
        _firstNameController.text = user['firstName'] ?? '';
        _lastNameController.text = user['lastName'] ?? '';
        _emailController.text = user['email'] ?? '';
        _phoneController.text = user['phone'] ?? '';
        selectedStationId = user['stationId'];
        isLoading = false;
      });
      
      // Load station name if user has a station ID
      if (selectedStationId != null) {
        _loadStationName();
      }
    }
  }

  Future<void> _loadStationName() async {
    if (selectedStationId == null) return;
    
    try {
      final station = await _profileService.getStationById(selectedStationId!);
      if (station != null) {
        setState(() {
          selectedStationName = station['name'];
        });
      }
    } catch (e) {
      print('Error loading station name: $e');
    }
  }

  Future<void> _loadStations() async {
    try {
      final stations = await _profileService.getAvailableStations();
      setState(() {
        availableStations = stations;
        // Set station name if we have a selected station ID
        if (selectedStationId != null) {
          final station = stations.firstWhere(
            (s) => s['_id'] == selectedStationId,
            orElse: () => {},
          );
          if (station.isNotEmpty) {
            selectedStationName = station['name'];
          }
        }
      });
    } catch (e) {
      print('Error loading stations: $e');
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      isSaving = true;
    });

    try {
      final updatedData = {
        '_id': userData?['_id'],
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': userData?['role'] ?? 'OFFICER',
        'stationId': selectedStationId,
        'skipAuthCheck': true, // Flag to bypass auth requirement on server
      };

      print('🔍 User data: $userData');
      print('🔍 User ID being sent: ${userData?['_id']}');

      // Check if user ID exists
      if (userData?['_id'] == null) {
        print('❌ User ID is null, cannot update profile');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to update profile: User ID not found. Please log in again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final success = await _profileService.updateProfile(updatedData);
      
      if (success) {
        // Update local user data immediately
        setState(() {
          userData = {
            ...userData!,
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'fullName': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
            'stationId': selectedStationId,
            'updatedAt': DateTime.now().toIso8601String(),
          };
        });
        
        // Update stored user data
        await _authService.updateStoredUserData(userData!);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update profile. Please try again.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        title: Text(
          'Profile',
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
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _authService.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          userData?['fullName'] ?? 'Officer',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          userData?['role'] ?? 'OFFICER',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Personal Information',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProfileField(
                    label: 'First Name',
                    controller: _firstNameController,
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  ProfileField(
                    label: 'Last Name',
                    controller: _lastNameController,
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  ProfileField(
                    label: 'Email',
                    controller: _emailController,
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  ProfileField(
                    label: 'Phone',
                    controller: _phoneController,
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  // Only show Station Assignment for ADMINISTRATOR, MANAGER, OFFICER roles
                  if (userData?['role'] != 'USER') ...[
                    Text(
                      'Station Assignment',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    StationSelector(
                      selectedStationId: selectedStationId,
                      selectedStationName: selectedStationName,
                      availableStations: availableStations,
                      onStationChanged: (stationId, stationName) {
                        setState(() {
                          selectedStationId = stationId;
                          selectedStationName = stationName;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Save Changes',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'User ID: ${userData?['_id'] ?? 'N/A'}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}