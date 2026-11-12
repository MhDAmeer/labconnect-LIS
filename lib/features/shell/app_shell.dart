import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session_controller.dart';
import '../home/home_screen.dart';
import '../menu/menu_screen.dart';
import '../orders/orders_screen.dart';
import '../patients/patients_screen.dart';
import '../results/results_screen.dart';

enum AppTab { home, patients, orders, results, menu }

/// Bottom navigation in the Sahatna style. Only the tabs the user's role
/// allows are shown; Home and Menu are always there.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _current = AppTab.home;

  /// Tabs are built the first time they are opened, not all at start-up, so
  /// we don't fire every list call just to show Home.
  final Set<AppTab> _opened = {AppTab.home};

  void _open(AppTab tab) {
    setState(() {
      _current = tab;
      _opened.add(tab);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final permissions = session.permissions;

    final tabs = <AppTab>[
      AppTab.home,
      if (permissions.canSeePatients) AppTab.patients,
      if (permissions.canSeeOrders) AppTab.orders,
      if (permissions.canSeeResults) AppTab.results,
      AppTab.menu,
    ];
    final active = tabs.contains(_current) ? _current : AppTab.home;

    return PopScope(
      // Android back from another tab goes to Home before leaving the app.
      canPop: active == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _open(AppTab.home);
      },
      child: Scaffold(
        // Changing the facility rebuilds every tab so each one reloads.
        body: KeyedSubtree(
          key: ValueKey<int?>(session.facilityId),
          child: IndexedStack(
            index: tabs.indexOf(active),
            children: [
              for (final tab in tabs)
                _opened.contains(tab) ? _page(tab) : const SizedBox.shrink(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tabs.indexOf(active),
          onDestinationSelected: (i) => _open(tabs[i]),
          destinations: [
            for (final tab in tabs) _destination(tab),
          ],
        ),
      ),
    );
  }

  Widget _page(AppTab tab) {
    switch (tab) {
      case AppTab.home:
        return HomeScreen(onOpenTab: _open);
      case AppTab.patients:
        return const PatientsScreen();
      case AppTab.orders:
        return const OrdersScreen();
      case AppTab.results:
        return const ResultsScreen();
      case AppTab.menu:
        return const MenuScreen();
    }
  }

  NavigationDestination _destination(AppTab tab) {
    switch (tab) {
      case AppTab.home:
        return const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        );
      case AppTab.patients:
        return const NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Patients',
        );
      case AppTab.orders:
        return const NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: 'Orders',
        );
      case AppTab.results:
        return const NavigationDestination(
          icon: Icon(Icons.science_outlined),
          selectedIcon: Icon(Icons.science),
          label: 'Results',
        );
      case AppTab.menu:
        return const NavigationDestination(
          icon: Icon(Icons.menu),
          selectedIcon: Icon(Icons.menu),
          label: 'Menu',
        );
    }
  }
}
