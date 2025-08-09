import 'package:fireout/cubit/bottom_nav_cubit.dart';
import 'package:fireout/services/auth_service.dart';
import 'package:fireout/user_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fireout/ui/screens/login/widgets/textfield.dart';
import 'dart:developer';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  TextEditingController usernameCtrl = TextEditingController();
  TextEditingController passwordCtrl = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
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
                  child: Image.asset('assets/images/fireout3_logo.png')),
            ),
            Container(
              margin: const EdgeInsets.only(left: 20, right: 20, top: 100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomTextField(
                    label: 'Username',
                    controller: usernameCtrl,
                    inputType: TextInputType.text,
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    label: 'Password',
                    controller: passwordCtrl,
                    inputType: TextInputType.text,
                    isVisible: true,
                    obscureText: true,
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
                      onPressed: isLoading ? null : handleLogin,
                      child: isLoading 
                        ? const CircularProgressIndicator()
                        : const Text('Login'),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ],
    );
  }

  Future<void> handleLogin() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final username = usernameCtrl.text.trim();
    final password = passwordCtrl.text.trim();

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
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      final error = await _authService.getErrorMessage(username, password);
      setState(() {
        errorMessage = error ?? 'Login failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BottomNavCubit, int>(
      listener: (context, state) {
        context.read<BottomNavCubit>().updateIndex(0);
      },
      builder: (context, state) {
        context.read<BottomNavCubit>().updateIndex(0);
        return Scaffold(
            backgroundColor: Theme.of(context).primaryColor,
            body: ConstrainedBox(
              constraints: const BoxConstraints.expand(),
              child: _buildBody(),
            ));
      },
    );
  }
}
