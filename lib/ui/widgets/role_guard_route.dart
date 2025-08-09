import 'package:flutter/material.dart';
import 'package:fireout/services/auth_service.dart';

class RoleGuardRoute extends StatefulWidget {
  final Widget child;
  final List<String> allowedRoles;
  final String? redirectRoute;

  const RoleGuardRoute({
    Key? key,
    required this.child,
    required this.allowedRoles,
    this.redirectRoute,
  }) : super(key: key);

  @override
  State<RoleGuardRoute> createState() => _RoleGuardRouteState();
}

class _RoleGuardRouteState extends State<RoleGuardRoute> {
  bool isLoading = true;
  bool hasAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final authService = AuthService();
    final userRole = await authService.getUserRole();
    
    setState(() {
      hasAccess = widget.allowedRoles.contains(userRole);
      isLoading = false;
    });

    if (!hasAccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redirectUser();
      });
    }
  }

  Future<void> _redirectUser() async {
    final authService = AuthService();
    final homeRoute = widget.redirectRoute ?? await authService.getAppropriateHomeRoute();
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, homeRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return hasAccess ? widget.child : const SizedBox.shrink();
  }
}