import 'auth_service.dart';

class PermissionService {
  static const Map<String, List<String>> rolePermissions = {
    'USER': [
      'report_incident',
      'view_own_incidents',
      'update_own_profile',
    ],
    'OFFICER': [
      'report_incident',
      'view_own_incidents',
      'view_assigned_incidents',
      'update_incident_status',
      'update_own_profile',
    ],
    'MANAGER': [
      'report_incident',
      'view_own_incidents',
      'view_all_incidents',
      'assign_incidents',
      'update_incident_status',
      'manage_officers',
      'view_statistics',
    ],
    'ADMINISTRATOR': [
      'report_incident',
      'view_own_incidents',
      'view_all_incidents',
      'assign_incidents',
      'update_incident_status',
      'manage_users',
      'manage_officers',
      'view_statistics',
      'system_settings',
    ],
  };

  static Future<bool> hasPermission(String permission) async {
    final authService = AuthService();
    final userRole = await authService.getUserRole();
    
    return rolePermissions[userRole]?.contains(permission) ?? false;
  }

  static Future<List<String>> getUserPermissions() async {
    final authService = AuthService();
    final userRole = await authService.getUserRole();
    
    return rolePermissions[userRole] ?? [];
  }
}

class RoleGuard {
  static Future<bool> canAccessRoute(String route) async {
    final authService = AuthService();
    final userRole = await authService.getUserRole();

    final Map<String, List<String>> routeAccess = {
      '/user-dashboard': ['USER'],
      '/report-incident': ['USER', 'OFFICER', 'MANAGER', 'ADMINISTRATOR'],
      '/user-incident-history': ['USER'],
      '/dashboard': ['OFFICER', 'MANAGER', 'ADMINISTRATOR'],
      '/incident-detail': ['OFFICER', 'MANAGER', 'ADMINISTRATOR'],
      '/admin-panel': ['ADMINISTRATOR'],
      '/profile': ['USER', 'OFFICER', 'MANAGER', 'ADMINISTRATOR'],
    };

    final allowedRoles = routeAccess[route];
    return allowedRoles?.contains(userRole) ?? false;
  }
}