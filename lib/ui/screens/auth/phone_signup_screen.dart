import 'package:fireout/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fireout/ui/screens/login/widgets/textfield.dart';

class PhoneSignupScreen extends StatefulWidget {
  const PhoneSignupScreen({Key? key}) : super(key: key);

  @override
  State<PhoneSignupScreen> createState() => _PhoneSignupScreenState();
}

class _PhoneSignupScreenState extends State<PhoneSignupScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String input) {
    String cleaned = input.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleaned.startsWith('63')) {
      cleaned = '+$cleaned';
    } else if (cleaned.startsWith('9') && cleaned.length == 10) {
      cleaned = '+63$cleaned';
    } else if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = '+63${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('+')) {
      cleaned = '+63$cleaned';
    }
    
    return cleaned;
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    final regex = RegExp(r'^\+63[0-9]{10}$');
    return regex.hasMatch(phoneNumber);
  }

  Future<void> _handleSignup() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phoneInput = _phoneController.text.trim();
    
    if (firstName.isEmpty || lastName.isEmpty || phoneInput.isEmpty) {
      setState(() {
        isLoading = false;
        errorMessage = 'Please fill in all fields';
      });
      return;
    }

    final formattedPhone = _formatPhoneNumber(phoneInput);
    
    if (!_isValidPhoneNumber(formattedPhone)) {
      setState(() {
        isLoading = false;
        errorMessage = 'Please enter a valid Philippine phone number';
      });
      return;
    }

    final result = await _authService.signupWithPhone(
      formattedPhone, 
      firstName, 
      lastName,
    );
    
    setState(() {
      isLoading = false;
    });

    if (result != null) {
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/otp-verification',
          arguments: formattedPhone,
        );
      }
    } else {
      final error = await _authService.getSignupErrorMessage(
        formattedPhone, 
        firstName, 
        lastName,
      );
      setState(() {
        errorMessage = error ?? 'Signup failed. Please try again.';
      });
    }
  }

  Widget _buildBody() {
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: Image.asset('assets/images/login_shade.png'),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 50, right: 35),
              child: SizedBox(
                width: 300,
                height: 300,
                child: Image.asset('assets/images/fireout3_logo.png'),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 20, right: 20, top: 50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Enter your details to get started',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  CustomTextField(
                    label: 'First Name',
                    controller: _firstNameController,
                    inputType: TextInputType.name,
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    label: 'Last Name',
                    controller: _lastNameController,
                    inputType: TextInputType.name,
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    inputType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s\(\)]')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _handleSignup,
                      child: isLoading 
                        ? const CircularProgressIndicator()
                        : const Text('Send OTP'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Already have an account? Login',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ConstrainedBox(
        constraints: const BoxConstraints.expand(),
        child: _buildBody(),
      ),
    );
  }
}