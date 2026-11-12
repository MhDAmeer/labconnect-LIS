import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/patient.dart';
import '../../data/repositories/patient_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/common_widgets.dart';
import '../orders/orders_screen.dart';

/// GET /patients/{mrn}/ - details plus an "Orders" button that lists this
/// patient's orders (patient_id is the patient's id, not the MRN).
class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key, required this.mrn, this.initial});

  final String mrn;

  /// The row we tapped, shown instantly while the full record loads.
  final Patient? initial;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  Patient? _patient;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _patient = widget.initial;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final patient =
          await context.read<PatientRepository>().byMrn(widget.mrn);
      if (!mounted) return;
      setState(() {
        _patient = patient;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSeeOrders =
        context.watch<SessionController>().permissions.canSeeOrders;
    final patient = _patient;

    return Scaffold(
      appBar: AppBar(title: const Text('Patient')),
      body: Builder(
        builder: (context) {
          if (_loading && patient == null) return const LoadingView();
          if (_error != null) {
            return ErrorView(message: _error!, onRetry: _load);
          }
          if (patient == null) {
            return const MessageView(
              icon: Icons.person_off_outlined,
              message: 'Not found',
            );
          }
          return _content(patient, canSeeOrders);
        },
      ),
    );
  }

  Widget _content(Patient patient, bool canSeeOrders) {
    final d = patient.demographics;
    final age = Formatters.ageFrom(d.dob);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              InitialsAvatar(patient.fullName, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.fullName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      patient.mrn,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!patient.isActive)
                const StatusChip(label: 'Inactive', color: AppColors.warning),
            ],
          ),
          if (canSeeOrders) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Orders'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OrdersScreen(
                    patientId: patient.id,
                    title: patient.fullName,
                    embedded: true,
                  ),
                ),
              ),
            ),
          ],
          const SectionTitle('Details'),
          OutlinedCard(
            child: Column(
              children: [
                InfoRow(label: 'Date of birth', value: Formatters.birthDate(d.dob)),
                const Divider(),
                InfoRow(label: 'Age', value: age == null ? null : '$age years'),
                const Divider(),
                InfoRow(label: 'Gender', value: Formatters.gender(d.gender)),
                const Divider(),
                InfoRow(label: 'Mobile', value: d.mobile),
                const Divider(),
                InfoRow(label: 'Email', value: d.email),
                const Divider(),
                InfoRow(label: 'Nationality', value: d.nationality),
                const Divider(),
                InfoRow(label: 'Facility', value: patient.facilityName),
                const Divider(),
                InfoRow(label: 'Registration', value: patient.registrationType),
              ],
            ),
          ),
          if (patient.insurances.isNotEmpty) ...[
            const SectionTitle('Insurance'),
            _noteList(patient.insurances, Icons.shield_outlined),
          ],
          if (patient.nextOfKin.isNotEmpty) ...[
            const SectionTitle('Next of kin'),
            _noteList(patient.nextOfKin, Icons.family_restroom_outlined),
          ],
        ],
      ),
    );
  }

  Widget _noteList(List<PatientNote> notes, IconData icon) {
    return Column(
      children: [
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedCard(
              child: Row(
                children: [
                  Icon(icon, color: AppColors.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (note.subtitle != null)
                          Text(
                            note.subtitle!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
