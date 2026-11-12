import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/session_controller.dart';

/// Bottom sheet to choose which of the user's assigned facilities the lists
/// are limited to. The choice is sent as `facility_id` on list calls.
Future<void> showFacilityPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final session = sheetContext.read<SessionController>();
      final facilities = session.facilities;

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Choose facility',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              if (facilities.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No facilities are assigned to your account.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    children: [
                      if (facilities.length > 1)
                        _FacilityTile(
                          title: 'All my facilities',
                          subtitle: 'Show data from every facility',
                          selected: session.facilityId == null,
                          onTap: () {
                            session.selectFacility(null);
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                      for (final f in facilities)
                        _FacilityTile(
                          title: f.name,
                          subtitle: f.code,
                          selected: session.facilityId == f.facilityId,
                          onTap: () {
                            session.selectFacility(f.facilityId);
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _FacilityTile extends StatelessWidget {
  const _FacilityTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: const Icon(Icons.apartment_outlined, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : const Icon(Icons.circle_outlined, color: AppColors.border),
    );
  }
}
