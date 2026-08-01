import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../auth/login_screen.dart';
import 'courier_hub_screen.dart';

class CourierShell extends ConsumerStatefulWidget {
  const CourierShell({super.key});

  @override
  ConsumerState<CourierShell> createState() => _CourierShellState();
}

class _CourierShellState extends ConsumerState<CourierShell> {
  int _index = 0;

  final _screens = const [
    CourierHubScreen(),
    Center(child: Text('Teslimat Geçmişi')),
  ];

  void _logout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kurye Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.two_wheeler_rounded),
            label: 'Aktif Siparişler',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Geçmiş',
          ),
        ],
      ),
    );
  }
}