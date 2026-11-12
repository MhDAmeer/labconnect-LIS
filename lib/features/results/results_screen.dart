import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/lab_result.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/common_widgets.dart';
import '../orders/orders_screen.dart';
import 'results_detail_screen.dart';

/// Results tab. The server needs something to search for (order number, MRN
/// or accession number), so nothing is listed until the user types one.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _search = TextEditingController();

  List<OrderResults> _orders = const [];
  bool _searched = false;
  bool _loading = false;
  String? _error;
  int _generation = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(String term) async {
    final query = term.trim();
    final generation = ++_generation;

    if (query.isEmpty) {
      setState(() {
        _orders = const [];
        _searched = false;
        _loading = false;
        _error = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    final facilityId = context.read<SessionController>().facilityId;
    final repository = context.read<OrderRepository>();

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found =
          await repository.results(search: query, facilityId: facilityId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _orders = found;
        _searched = true;
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
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 12),
            child: Text(
              'Laboratory Results',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SearchField(
              controller: _search,
              hint: 'Order number, MRN or accession',
              onSubmitted: _run,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: () => _run(_search.text));
    }
    if (!_searched) {
      return const MessageView(
        icon: Icons.manage_search,
        message:
            'Search by order number, MRN or accession number to see results.',
      );
    }
    if (_orders.isEmpty) {
      return const MessageView(
        icon: Icons.science_outlined,
        message: 'No results found.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final o = _orders[i];
        return OutlinedCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ResultsDetailScreen(
                orderId: o.orderId,
                orderNumber: o.orderNumber,
                initial: o,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      o.orderNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusChip(
                    label: orderStatusLabel(o.status),
                    color: orderStatusColor(o.status),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [o.patient.name, o.patient.mrn].whereType<String>().join(' · '),
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    Formatters.dateTime(o.orderedAt, zone: o.facilityTimeZone),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${o.results.length} tests',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (o.abnormalCount > 0) ...[
                    const SizedBox(width: 8),
                    StatusChip(
                      label: '${o.abnormalCount} abnormal',
                      color: AppColors.abnormal,
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
