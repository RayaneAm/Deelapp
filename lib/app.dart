import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/devices/device_list_screen.dart';
import 'features/devices/add_device_screen.dart';
import 'features/devices/device_detail_screen.dart';
import 'features/rentals/my_rentals_screen.dart';
import 'features/rentals/owner_dashboard_screen.dart';

class DeelApp extends StatelessWidget {
  const DeelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DeelApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      routerConfig: _buildRouter(),
    );
  }
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/devices', builder: (_, __) => const DeviceListScreen()),
      GoRoute(path: '/add-device', builder: (_, __) => const AddDeviceScreen()),
      GoRoute(
        path: '/device/:id',
        builder: (_, state) =>
            DeviceDetailScreen(deviceId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/my-rentals', builder: (_, __) => const MyRentalsScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const OwnerDashboardScreen()),
    ],
  );
}