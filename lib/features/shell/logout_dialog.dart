import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/session_controller.dart';

/// Asks first, then logs out. Reachable from Home and from Menu, so the user
/// can log out from any screen they land on.
Future<void> confirmLogout(BuildContext context) async {
  final session = context.read<SessionController>();

  final yes = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Log out?'),
      content: const Text(
        'You will need to sign in again to see patient data.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.abnormal),
          child: const Text('Log out'),
        ),
      ],
    ),
  );

  if (yes == true) {
    await session.logout();
  }
}
