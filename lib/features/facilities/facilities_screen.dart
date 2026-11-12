import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/facility.dart';
import '../../data/repositories/facility_repository.dart';
import '../../widgets/common_widgets.dart';
import 'facility_detail_screen.dart';

/// GET /facilities/ - searchable list, tap to open one.
class FacilitiesScreen extends StatefulWidget {
  const FacilitiesScreen({super.key});

  @override
  State<FacilitiesScreen> createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends State<FacilitiesScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  List<Facility> _facilities = const [];
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final repository = context.read<FacilityRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await repository.list(search: _search.text);
      if (!mounted || generation != _generation) return;
      setState(() {
        _facilities = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Facilities')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(
              controller: _search,
              hint: 'Facility name or code',
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                _debounce?.cancel();
                _load();
              },
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_facilities.isEmpty) {
      return const MessageView(
        icon: Icons.apartment_outlined,
        message: 'No facilities found.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _facilities.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final f = _facilities[i];
          return OutlinedCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FacilityDetailScreen(id: f.id, initial: f),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.apartment_rounded,
                    color: AppColors.primary, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [f.code, if (f.city != null) f.city!].join(' · '),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!f.isActive)
                  const StatusChip(label: 'Inactive', color: AppColors.warning),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          );
        },
      ),
    );
  }
}
