import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/session_controller.dart';
import '../../widgets/common_widgets.dart';
import '../facilities/facilities_screen.dart';
import '../shell/facility_picker.dart';
import '../shell/logout_dialog.dart';

/// Who is signed in, which facility is active, and Logout.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    final facility = session.selectedFacility;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Center(
            child: Text(
              'Menu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedCard(
            child: Row(
              children: [
                InitialsAvatar(
                  (user?.fullName.isNotEmpty ?? false)
                      ? user!.fullName
                      : (user?.username ?? ''),
                  size: 58,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (user?.fullName.isNotEmpty ?? false)
                            ? user!.fullName
                            : (user?.username ?? ''),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [user?.username, user?.role]
                            .whereType<String>()
                            .join(' · '),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (session.tenant != null)
                        Text(
                          session.tenant!.name,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MenuItem(
            icon: Icons.apartment_outlined,
            title: 'Facility',
            subtitle: facility?.name ??
                (session.facilities.isEmpty
                    ? 'None assigned'
                    : 'All my facilities'),
            onTap: () => showFacilityPicker(context),
          ),
          if (session.permissions.canSeeFacilities) ...[
            const SizedBox(height: 10),
            _MenuItem(
              icon: Icons.list_alt_outlined,
              title: 'Facilities',
              subtitle: 'Browse facilities',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FacilitiesScreen(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _MenuItem(
            icon: Icons.logout,
            title: 'Log out',
            color: AppColors.abnormal,
            onTap: () => confirmLogout(context),
          ),
          const SizedBox(height: 28),
          const Center(
            child: Text(
              'LabConnect Admin · read-only',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color == AppColors.primary
                        ? AppColors.textPrimary
                        : color,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
