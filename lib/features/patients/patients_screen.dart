import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/patient.dart';
import '../../data/repositories/patient_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/common_widgets.dart';
import 'patient_detail_screen.dart';

/// Search box + paged list of patients. Opens the details by MRN.
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  static const int _pageSize = 20;

  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  final List<Patient> _patients = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// Bumped on every new search so a slow, old answer can't overwrite a
  /// newer one.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final nearEnd =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 300;
    if (nearEnd && _hasMore && !_loading && !_loadingMore) {
      _load();
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _load(reset: true);
    });
  }

  Future<void> _load({bool reset = false}) async {
    final generation = reset ? ++_generation : _generation;
    final facilityId = context.read<SessionController>().facilityId;
    final repository = context.read<PatientRepository>();

    setState(() {
      _error = null;
      if (reset) {
        _loading = true;
        _page = 1;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await repository.search(
        search: _search.text,
        facilityId: facilityId,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _patients.clear();
        _patients.addAll(result.patients);
        _hasMore = result.hasMore;
        _page += 1;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 12),
            child: Text(
              'Patients',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SearchField(
              controller: _search,
              hint: 'Name, MRN, ID or phone',
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                _debounce?.cancel();
                _load(reset: true);
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();

    if (_error != null && _patients.isEmpty) {
      return ErrorView(message: _error!, onRetry: () => _load(reset: true));
    }
    if (_patients.isEmpty) {
      return const MessageView(
        icon: Icons.person_search_outlined,
        message: 'No patients found.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _patients.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _patients.length) return _footer();
          return PatientCard(
            patient: _patients[index],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PatientDetailScreen(
                  mrn: _patients[index].mrn,
                  initial: _patients[index],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _footer() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.abnormal)),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    return const SizedBox(height: 8);
  }
}

class PatientCard extends StatelessWidget {
  const PatientCard({super.key, required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = patient.demographics;
    final age = Formatters.ageFrom(d.dob);
    final line2 = [
      if (age != null) '$age yrs',
      if (d.gender != null) Formatters.gender(d.gender),
    ].join(' · ');

    return OutlinedCard(
      onTap: onTap,
      child: Row(
        children: [
          InitialsAvatar(patient.fullName),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  patient.mrn,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (line2.isNotEmpty)
                  Text(
                    line2,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
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
