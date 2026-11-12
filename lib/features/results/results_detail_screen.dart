import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/services/report_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/lab_result.dart';
import '../../data/repositories/order_repository.dart';
import '../../widgets/common_widgets.dart';

/// One order's results with the patient banner and the PDF report buttons
/// ("View report" / "Download PDF").
class ResultsDetailScreen extends StatefulWidget {
  const ResultsDetailScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    this.initial,
  });

  final int orderId;
  final String orderNumber;

  /// Already loaded by the Results tab; null when coming from an order.
  final OrderResults? initial;

  @override
  State<ResultsDetailScreen> createState() => _ResultsDetailScreenState();
}

class _ResultsDetailScreenState extends State<ResultsDetailScreen> {
  OrderResults? _data;
  bool _loading = true;
  String? _error;

  bool _viewing = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initial;
    if (_data != null) {
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final repository = context.read<OrderRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // From an order screen we search by its order number (guide, section 8)
      // and pick the entry that is exactly this order.
      final found = await repository.results(search: widget.orderNumber);
      if (!mounted) return;
      OrderResults? match;
      for (final o in found) {
        if (o.orderId == widget.orderId) match = o;
      }
      setState(() {
        _data = match;
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

  Future<void> _view(OrderResults order) async {
    if (_viewing || _downloading) return;
    setState(() => _viewing = true);
    try {
      await context.read<ReportService>().view(order);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _viewing = false);
    }
  }

  Future<void> _download(OrderResults order) async {
    if (_viewing || _downloading) return;
    setState(() => _downloading = true);
    try {
      await context.read<ReportService>().download(order);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingView();
          if (_error != null) {
            return ErrorView(message: _error!, onRetry: _load);
          }
          final data = _data;
          if (data == null) {
            return const MessageView(
              icon: Icons.science_outlined,
              message: 'No results are available for this order yet.',
            );
          }
          return _content(data);
        },
      ),
    );
  }

  Widget _content(OrderResults data) {
    // Keep the lab's own order, grouped under the battery (panel) name.
    final groups = <String, List<LabResult>>{};
    for (final r in data.results) {
      groups.putIfAbsent(r.batteryName ?? '', () => []).add(r);
    }
    final pending = data.results.where((r) => r.isPending).length;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _PatientBanner(data: data),
          const SizedBox(height: 14),
          OutlinedCard(
            child: Column(
              children: [
                InfoRow(label: 'Normal Results', value: '${data.normalCount}'),
                InfoRow(
                  label: 'Abnormal Results',
                  value: '${data.abnormalCount}',
                ),
                if (pending > 0) InfoRow(label: 'Pending', value: '$pending'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_viewing || _downloading) ? null : () => _view(data),
                  icon: _viewing ? const _Spinner() : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('View report'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      (_viewing || _downloading) ? null : () => _download(data),
                  icon: _downloading
                      ? const _Spinner(color: Colors.white)
                      : const Icon(Icons.download_rounded),
                  label: const Text('Download PDF'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SectionTitle('Test Results'),
          if (data.results.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No results have been entered yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          for (final entry in groups.entries) ...[
            if (entry.key.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            for (final r in entry.value) _ResultTile(result: r),
          ],
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
    );
  }
}

/// Name, MRN, age, gender, DOB, accession number(s) and encounter ID.
class _PatientBanner extends StatelessWidget {
  const _PatientBanner({required this.data});

  final OrderResults data;

  @override
  Widget build(BuildContext context) {
    final p = data.patient;
    final age = Formatters.ageFrom(p.dob);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF0A4DA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.name ?? '-',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.orderNumber,
            style: const TextStyle(color: Color(0xFFCCDAF5), fontSize: 14),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 22,
            runSpacing: 12,
            children: [
              _fact('MRN', p.mrn),
              _fact('Age', age == null ? null : '$age yrs'),
              _fact('Gender', Formatters.gender(p.gender)),
              _fact('DOB', Formatters.birthDate(p.dob)),
              _fact(
                data.accessions.length > 1 ? 'Accessions' : 'Accession',
                data.accessions.isEmpty ? null : data.accessions.join(', '),
              ),
              _fact('Encounter', data.encounterCode),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fact(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB8C7EA), fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          (value == null || value.isEmpty) ? '-' : value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// One result in the layout of the "Test Results" screenshot: name on the
/// left with the big value under it, reference range on the right.
class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final LabResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final abnormal = !r.isPending && r.flag.isAbnormal;
    final valueColor = r.isPending
        ? AppColors.textMuted
        : (abnormal ? AppColors.abnormal : AppColors.textPrimary);
    final range = r.displayRange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: abnormal
              ? AppColors.abnormal.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.testName,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        r.displayValue,
                        style: TextStyle(
                          fontSize: r.isPending ? 18 : 26,
                          fontWeight: FontWeight.w800,
                          color: valueColor,
                        ),
                      ),
                    ),
                    if (!r.isPending && r.unit != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        r.unit!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    if (abnormal && r.flag.label.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      StatusChip(
                        label: r.flag.label,
                        color: AppColors.abnormal,
                      ),
                    ],
                  ],
                ),
                if (r.comments != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    r.comments!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (range != null)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Reference\nRange',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.unit == null ? range : '$range ${r.unit}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
