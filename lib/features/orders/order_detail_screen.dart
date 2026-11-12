import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/common_widgets.dart';
import '../results/results_detail_screen.dart';
import 'orders_screen.dart';

/// GET /orders/orders/{order_id}/ - everything for one order, with a button
/// that goes on to the results.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId, this.summary});

  final int orderId;

  /// Row from the list, used for the time zone while the details load.
  final OrderSummary? summary;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderDetail? _order;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = context.read<OrderRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await repository.details(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Order')),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingView();
          if (_error != null) {
            return ErrorView(message: _error!, onRetry: _load);
          }
          final order = _order;
          if (order == null) {
            return const MessageView(
              icon: Icons.assignment_outlined,
              message: 'Not found',
            );
          }
          return _content(order);
        },
      ),
    );
  }

  Widget _content(OrderDetail o) {
    final zone = o.facilityTimeZone ?? widget.summary?.facilityTimeZone;
    final canSeeResults =
        context.watch<SessionController>().permissions.canSeeResults;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  o.orderNumber,
                  style: const TextStyle(
                    fontSize: 22,
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
          if (canSeeResults) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.science_outlined),
              label: const Text('View results'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ResultsDetailScreen(
                    orderId: o.orderId,
                    orderNumber: o.orderNumber,
                  ),
                ),
              ),
            ),
          ],
          const SectionTitle('Patient'),
          OutlinedCard(
            child: Column(
              children: [
                InfoRow(label: 'Name', value: o.patientName),
                const Divider(),
                InfoRow(label: 'MRN', value: o.patientMrn),
                const Divider(),
                InfoRow(
                  label: 'Date of birth',
                  value: Formatters.birthDate(o.patientDob),
                ),
                const Divider(),
                InfoRow(label: 'Gender', value: Formatters.gender(o.patientGender)),
              ],
            ),
          ),
          const SectionTitle('Order details'),
          OutlinedCard(
            child: Column(
              children: [
                InfoRow(label: 'Encounter', value: o.encounterCode),
                const Divider(),
                InfoRow(label: 'Facility', value: o.facilityName),
                const Divider(),
                InfoRow(label: 'Priority', value: o.priorityName),
                const Divider(),
                InfoRow(label: 'Physician', value: o.physicianName),
                const Divider(),
                InfoRow(
                  label: 'Accession',
                  value: o.accessions.isEmpty ? null : o.accessions.join('\n'),
                ),
                if (o.clinicalIndication != null) ...[
                  const Divider(),
                  InfoRow(label: 'Indication', value: o.clinicalIndication),
                ],
              ],
            ),
          ),
          const SectionTitle('Timeline'),
          OutlinedCard(
            child: Column(
              children: [
                InfoRow(label: 'Ordered', value: Formatters.dateTime(o.orderedAt, zone: zone)),
                const Divider(),
                InfoRow(label: 'Collected', value: Formatters.dateTime(o.collectedAt, zone: zone)),
                const Divider(),
                InfoRow(label: 'In lab', value: Formatters.dateTime(o.inLabAt, zone: zone)),
                const Divider(),
                InfoRow(label: 'Completed', value: Formatters.dateTime(o.completedAt, zone: zone)),
              ],
            ),
          ),
          if (o.tests.isNotEmpty) ...[
            SectionTitle('Tests (${o.tests.length})'),
            for (final t in o.tests)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.testName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [t.specimenType, t.accessionNumber]
                                  .whereType<String>()
                                  .join(' · '),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (t.status != null)
                        StatusChip(
                          label: orderStatusLabel(t.status!),
                          color: orderStatusColor(t.status!),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
