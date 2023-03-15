import 'package:flutter/material.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'User Dashboard',
        home: Scaffold(
            appBar: AppBar(
              title: const Text('User Dashboard'),
            ),
            body: Center(
              child: ElevatedButton(
                child: const Text('Go Back'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            )));
  }
}
