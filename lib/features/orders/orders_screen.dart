import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/common_widgets.dart';
import 'order_detail_screen.dart';

/// GET /orders/orders/ - used both as the Orders tab and, with [patientId],
/// as a patient's order list opened from the patient details.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    this.patientId,
    this.title = 'Orders',
    this.embedded = false,
  });

  final int? patientId;
  final String title;

  /// True when pushed on top of another screen (shows a back arrow).
  final bool embedded;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late OrderFilter _filter;

  List<OrderSummary> _orders = const [];
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    // The list isn't paged by the server, so the tab starts with the last
    // 30 days to keep it short. A patient's own list starts unfiltered.
    final now = DateTime.now();
    _filter = OrderFilter(
      patientId: widget.patientId,
      dateFrom: widget.patientId == null
          ? DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 30))
          : null,
    );
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final facilityId = context.read<SessionController>().facilityId;
    final repository = context.read<OrderRepository>();

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders =
          await repository.list(facilityId: facilityId, filter: _filter);
      if (!mounted || generation != _generation) return;
      setState(() {
        _orders = orders;
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

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: (_filter.dateFrom != null && _filter.dateTo != null)
          ? DateTimeRange(start: _filter.dateFrom!, end: _filter.dateTo!)
          : null,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _filter = _filter.copyWith(dateFrom: picked.start, dateTo: picked.end);
    });
    _load();
  }

  void _clearFilters() {
    setState(() {
      _filter = _filter.copyWith(clearStatus: true, clearDates: true);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        _filterBar(),
        Expanded(child: _body()),
      ],
    );

    if (widget.embedded) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: body,
      );
    }
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _filterBar() {
    final dateText = (_filter.dateFrom == null && _filter.dateTo == null)
        ? 'Any date'
        : '${_filter.dateFrom == null ? 'Start' : Formatters.pickedDate(_filter.dateFrom!)}'
            ' - ${_filter.dateTo == null ? 'today' : Formatters.pickedDate(_filter.dateTo!)}';

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          // "All" uses a text value because a null value would be treated as
          // a dismissed menu by PopupMenuButton.
          PopupMenuButton<String>(
            onSelected: (value) {
              final status = OrderStatus.tryParse(value);
              setState(() {
                _filter = status == null
                    ? _filter.copyWith(clearStatus: true)
                    : _filter.copyWith(status: status);
              });
              _load();
            },
            itemBuilder: (_) => [
              const PopupMenuItem<String>(
                value: 'ALL',
                child: Text('All statuses'),
              ),
              for (final s in OrderStatus.values)
                PopupMenuItem<String>(value: s.apiValue, child: Text(s.label)),
            ],
            child: _FilterChip(
              icon: Icons.filter_list,
              label: _filter.status?.label ?? 'All statuses',
              active: _filter.status != null,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _pickDates,
            child: _FilterChip(
              icon: Icons.date_range_outlined,
              label: dateText,
              active: _filter.dateFrom != null || _filter.dateTo != null,
            ),
          ),
          if (_filter.isActive) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: _clearFilters, child: const Text('Clear')),
          ],
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_orders.isEmpty) {
      return const MessageView(
        icon: Icons.assignment_outlined,
        message: 'No orders found for these filters.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => OrderCard(
          order: _orders[i],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OrderDetailScreen(
                orderId: _orders[i].orderId,
                summary: _orders[i],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color orderStatusColor(String status) {
  switch (status) {
    case 'VERIFIED':
    case 'COMPLETED':
      return AppColors.normal;
    case 'CANCELLED':
      return AppColors.abnormal;
    case 'RESULTED':
      return AppColors.accent;
    case 'ORDERED':
      return AppColors.textSecondary;
    default:
      return AppColors.warning;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? AppColors.chip : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppColors.primary : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onTap});

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              StatusChip(
                label: orderStatusLabel(order.status),
                color: orderStatusColor(order.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [order.patientName, order.patientMrn]
                .whereType<String>()
                .join(' · '),
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                Formatters.dateTime(
                  order.orderedAt,
                  zone: order.facilityTimeZone,
                ),
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),
              if (order.priorityName != null) ...[
                const Text('  ·  ',
                    style: TextStyle(color: AppColors.textMuted)),
                Flexible(
                  child: Text(
                    order.priorityName!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
