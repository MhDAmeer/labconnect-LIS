import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/session_controller.dart';
import '../facilities/facilities_screen.dart';
import '../shell/app_shell.dart';
import '../shell/facility_picker.dart';
import '../shell/logout_dialog.dart';

/// Header, welcome banner and the Quick Actions tiles the role allows.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  final ValueChanged<AppTab> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final permissions = session.permissions;

    final tiles = <_Tile>[
      if (permissions.canSeePatients)
        _Tile(
          label: 'Patients',
          icon: Icons.people_alt_rounded,
          onTap: () => onOpenTab(AppTab.patients),
        ),
      if (permissions.canSeeFacilities)
        _Tile(
          label: 'Facilities',
          icon: Icons.apartment_rounded,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const FacilitiesScreen()),
          ),
        ),
      if (permissions.canSeeOrders)
        _Tile(
          label: 'Orders',
          icon: Icons.assignment_rounded,
          onTap: () => onOpenTab(AppTab.orders),
        ),
      if (permissions.canSeeResults)
        _Tile(
          label: 'Results',
          icon: Icons.science_rounded,
          onTap: () => onOpenTab(AppTab.results),
        ),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Header(
            name: session.user?.greetingName ?? '',
            facilityLabel: _facilityLabel(session),
            onFacilityTap: () => showFacilityPicker(context),
            onLogout: () => confirmLogout(context),
          ),
          const SizedBox(height: 18),
          const _WelcomeBanner(),
          const SizedBox(height: 26),
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (tiles.isEmpty)
            const _NoAccess()
          else
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
              children: [for (final t in tiles) _TileCard(tile: t)],
            ),
        ],
      ),
    );
  }

  String _facilityLabel(SessionController session) {
    final selected = session.selectedFacility;
    if (selected != null) {
      return selected.code.isNotEmpty ? selected.code : selected.name;
    }
    return session.facilities.isEmpty ? 'No facility' : 'All facilities';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.facilityLabel,
    required this.onFacilityTap,
    required this.onLogout,
  });

  final String name;
  final String facilityLabel;
  final VoidCallback onFacilityTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.chip,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.person, color: AppColors.primary, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Hi, ',
                  style: TextStyle(fontWeight: FontWeight.w400),
                ),
                TextSpan(
                  text: name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 24, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: 8),
        // Facility "pill" - the same place the Arabic switch sits in the
        // Sahatna header.
        Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(26),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onFacilityTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        facilityLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Round outlined button where Sahatna has "SOS".
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onLogout,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Tooltip(
              message: 'Log out',
              child: Icon(Icons.logout, color: AppColors.primary, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      padding: const EdgeInsets.fromLTRB(22, 22, 12, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF0A4DA8), Color(0xFF0089C9)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome to LabConnect!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Patients, orders and results from your lab, at your fingertips.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.biotech_rounded,
            size: 84,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }
}

class _Tile {
  const _Tile({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _TileCard extends StatelessWidget {
  const _TileCard({required this.tile});

  final _Tile tile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: tile.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tile.icon, size: 34, color: AppColors.primary),
              const SizedBox(height: 10),
              Text(
                tile.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: AppColors.textSecondary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Your account doesn't have access to anything in this app yet. "
              'Please ask your lab administrator to update your role.',
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
