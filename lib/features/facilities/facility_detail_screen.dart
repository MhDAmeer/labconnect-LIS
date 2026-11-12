import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/facility.dart';
import '../../data/repositories/facility_repository.dart';
import '../../widgets/common_widgets.dart';

/// GET /facilities/{id}/ - 403 if the user isn't assigned to it.
class FacilityDetailScreen extends StatefulWidget {
  const FacilityDetailScreen({super.key, required this.id, this.initial});

  final int id;
  final Facility? initial;

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  Facility? _facility;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _facility = widget.initial;
    _load();
  }

  Future<void> _load() async {
    final repository = context.read<FacilityRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final facility = await repository.details(widget.id);
      if (!mounted) return;
      setState(() {
        _facility = facility;
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
    final f = _facility;
    return Scaffold(
      appBar: AppBar(title: const Text('Facility')),
      body: Builder(
        builder: (context) {
          if (_loading && f == null) return const LoadingView();
          if (_error != null) {
            return ErrorView(message: _error!, onRetry: _load);
          }
          if (f == null) {
            return const MessageView(
              icon: Icons.apartment_outlined,
              message: 'Not found',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                f.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              OutlinedCard(
                child: Column(
                  children: [
                    InfoRow(label: 'Code', value: f.code),
                    const Divider(),
                    InfoRow(label: 'Type', value: f.facilityType),
                    const Divider(),
                    InfoRow(label: 'Prefix', value: f.prefix),
                    const Divider(),
                    InfoRow(label: 'Group', value: f.groupName),
                    const Divider(),
                    InfoRow(label: 'Status', value: f.isActive ? 'Active' : 'Inactive'),
                    const Divider(),
                    InfoRow(label: 'Default', value: f.isDefault ? 'Yes' : 'No'),
                  ],
                ),
              ),
              const SectionTitle('Contact'),
              OutlinedCard(
                child: Column(
                  children: [
                    InfoRow(
                      label: 'Address',
                      value: f.addressLines.isEmpty
                          ? null
                          : f.addressLines.join('\n'),
                    ),
                    const Divider(),
                    InfoRow(label: 'Phone', value: f.phoneNumber),
                    const Divider(),
                    InfoRow(label: 'Fax', value: f.faxNumber),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
