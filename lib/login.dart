import 'package:fireout/services/auth_service.dart';
import 'package:fireout/user_dashboard.dart';
import 'package:flutter/material.dart';
import 'dart:developer';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Login')),
        body: Container(
          margin: const EdgeInsets.all(64),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 10),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : handleLogin,
                  child: isLoading 
                    ? const CircularProgressIndicator()
                    : const Text('Login'),
                ),
              ),
            ],
          ),
        ));
  }

  Future<void> handleLogin() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        isLoading = false;
        errorMessage = 'Please enter both username and password';
      });
      return;
    }

    final result = await _authService.login(username, password);
    
    setState(() {
      isLoading = false;
    });

    if (result != null) {
      log('Login successful', name: 'fireout');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UserDashboard())
      );
    } else {
      final error = await _authService.getErrorMessage(username, password);
      setState(() {
        errorMessage = error ?? 'Login failed. Please try again.';
      });
    }
  }
}
