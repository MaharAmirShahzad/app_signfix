import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/app_utils.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../payment/payment_screen.dart';
import '../orders/order_detail_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.api, this.tabNotifier});
  final ApiClient api;
  final ValueNotifier<int>? tabNotifier;
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late Future<List<List<dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _future = Future.wait([
      widget.api.orders(),
      widget.api.services(),
      widget.api.getQuotations(),
      widget.api.getPayments(),
    ]);
    // Listen to tab switch from home screen stat tiles
    widget.tabNotifier?.addListener(_onTabNotify);
  }

  void _onTabNotify() {
    final idx = widget.tabNotifier?.value ?? 0;
    if (mounted && idx >= 0 && idx < 3) {
      _tab.animateTo(idx);
    }
  }

  @override
  void dispose() {
    widget.tabNotifier?.removeListener(_onTabNotify);
    _tab.dispose();
    super.dispose();
  }

  // Sync reload — used by tabNotifier + manual refresh
  void _load() {
    if (!mounted) return;
    final f = Future.wait([
      widget.api.orders(),
      widget.api.services(),
      widget.api.getQuotations(),
      widget.api.getPayments(),
    ]);
    setState(() => _future = f);
  }

  void _handleAuthError() async {
    await widget.api.logout();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  void _reload() {
    setState(() => _future = Future.wait([
      widget.api.orders(),
      widget.api.services(),
      widget.api.getQuotations(),
      widget.api.getPayments(),
    ]));
  }

  Future<void> _refresh() async {
    _load();
    await _future;
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed': case 'delivered': return AppColors.success;
      case 'in_production': case 'work_in_progress': case 'accepted': return AppColors.gold;
      case 'pending': case 'assigned': return AppColors.warning;
      case 'cancelled': return AppColors.danger;
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.navyDeep,
    appBar: AppBar(
      backgroundColor: AppColors.navyDark,
      title: const Text('My Activity',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w800)),
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
          onPressed: _reload,
        ),
      ],
    ),
    body: Column(
    children: [
      // Tab bar — dark theme
      Container(
        color: AppColors.navyDark,
        child: TabBar(
          controller: _tab,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.gold,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'My Orders'),
            Tab(text: 'My Services'),
            Tab(text: 'Quotations'),
          ],
        ),
      ),

      Expanded(
        child: FutureBuilder<List<List<dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: AppColors.gold));
            }
            if (snap.hasError) {
              final errMsg = snap.error.toString();
              final isAuthError = errMsg.toLowerCase().contains('authentication') ||
                  errMsg.toLowerCase().contains('unauthorized') ||
                  errMsg.toLowerCase().contains('401');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isAuthError ? AppColors.warning.withValues(alpha: .1) : AppColors.danger.withValues(alpha: .1),
                        shape: BoxShape.circle,
                        border: Border.all(color: isAuthError ? AppColors.warning : AppColors.danger, width: 2),
                      ),
                      child: Icon(isAuthError ? Icons.lock_outline_rounded : Icons.error_outline_rounded,
                          color: isAuthError ? AppColors.warning : AppColors.danger, size: 40),
                    ),
                    const SizedBox(height: 20),
                    Text(isAuthError ? 'Session Expired' : 'Could Not Load Activity',
                        style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(isAuthError ? 'Your session has expired. Please sign in again.' : 'Unable to load data. Please try again.',
                        style: const TextStyle(color: AppColors.textLight, fontSize: 13), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    SizedBox(width: double.infinity,
                      child: isAuthError
                          ? FilledButton.icon(onPressed: _handleAuthError, icon: const Icon(Icons.login_rounded), label: const Text('Sign In Again'))
                          : OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again')),
                    ),
                  ]),
                ),
              );
            }
            final orders   = snap.data![0];
            final services = snap.data![1];
            final quotations = snap.data![2];
            final payments = snap.data![3];
            return TabBarView(
              controller: _tab,
              children: [
                _OrdersList(orders: orders, statusColor: _statusColor, api: widget.api, onRefresh: _refresh),
                _ServicesList(services: services, statusColor: _statusColor, onRefresh: _refresh),
                _QuotationsList(
                  quotations: quotations,
                  payments: payments,
                  api: widget.api,
                  onRefresh: _refresh,
                ),
              ],
            );
          },
        ),
      ),
    ],
    ),
  );
}

// ── Orders List ───────────────────────────────────────────────────────────────
class _QuotationsList extends StatelessWidget {
  const _QuotationsList({
    required this.quotations,
    required this.payments,
    required this.api,
    required this.onRefresh,
  });

  final List<dynamic> quotations;
  final List<dynamic> payments;
  final ApiClient api;
  final Future<void> Function() onRefresh;

  Future<void> _approve(
    BuildContext context,
    Map<String, dynamic> quotation,
  ) async {
    try {
      await api.approveQuotation(quotation['quotationNo'].toString());
      await onRefresh();
    } catch (error) {
      if (context.mounted) showAppError(context, error);
    }
  }

  Future<void> _pay(
    BuildContext context,
    Map<String, dynamic> quotation,
    String type,
  ) async {
    try {
      final profile = await api.getProfile();
      if (!context.mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            api: api,
            orderId: quotation['orderNo']?.toString() ?? '',
            quotationNo: quotation['quotationNo'].toString(),
            paymentType: type,
            amount: (quotation['finalAmount'] as num?)?.toDouble() ?? 0,
            customerName: profile['name']?.toString() ?? 'Customer',
            customerEmail:
                profile['email']?.toString() ?? 'customer@signfix.in',
            customerPhone: (profile['mobile'] ?? profile['phone'])
                    ?.toString() ??
                '',
            description: 'Approved final quotation',
            onSuccess: (_) {},
            onFailure: (_) {},
          ),
        ),
      );
      await onRefresh();
    } catch (error) {
      if (context.mounted) showAppError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (quotations.isEmpty) {
      return const _EmptyState(
        icon: Icons.request_quote_outlined,
        label: 'No quotations yet.\nYour final quotations will appear here.',
      );
    }
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.navyDark,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: quotations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final quotation =
              quotations[index] as Map<String, dynamic>;
          final status = quotation['status']?.toString() ?? 'sent';
          final actions = quotation['availableActions'] as List? ?? [];
          final payment = quotation['payments'] as Map? ?? {};
          final options = payment['options'] as List? ?? [];
          final quotePayments = payments
              .whereType<Map<String, dynamic>>()
              .where((entry) => entry['quotationNo'] == quotation['quotationNo'])
              .toList();
          final paidAmount = quotePayments
              .where((entry) => [
                    'captured',
                    'partially_refunded',
                    'refunded',
                  ].contains(entry['status']))
              .fold<double>(
                0,
                (total, entry) =>
                    total +
                    ((entry['amount'] as num?)?.toDouble() ?? 0) -
                    ((entry['refundedAmount'] as num?)?.toDouble() ?? 0),
              );
          final pendingPayment = quotePayments.any((entry) =>
              ['created', 'pending', 'authorized'].contains(entry['status']));
          final finalAmount =
              (quotation['finalAmount'] as num?)?.toDouble() ?? 0;
          final remaining = (finalAmount - paidAmount).clamp(0, finalAmount);
          final advanceDue =
              ((finalAmount * 0.25) - paidAmount).clamp(0, remaining);
          final color = switch (status) {
            'approved' => AppColors.success,
            'rejected' || 'expired' || 'cancelled' => AppColors.danger,
            'sent' || 'viewed' => AppColors.warning,
            _ => AppColors.textMuted,
          };
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.navyDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.navyLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined,
                        color: AppColors.gold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quotation['quotationNo']?.toString() ?? '',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Order ${quotation['orderNo'] ?? ''}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Badge(humanize(status), color),
                  ],
                ),
                const Divider(height: 22, color: AppColors.navyLight),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Final quotation amount',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                    ),
                    Text(
                      money(quotation['finalAmount']),
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                if (quotation['validUntil'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      'Valid until ${quotation['validUntil']}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                if (actions.contains('approve')) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _approve(context, quotation),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Approve final quotation'),
                    ),
                  ),
                ],
                if (status == 'approved' && payment['enabled'] == true) ...[
                  const SizedBox(height: 12),
                  if (pendingPayment)
                    const Text(
                      'A payment is processing. Refresh this screen to check its status before paying again.',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                      ),
                    ),
                  if (!pendingPayment &&
                      options.contains('advance') &&
                      advanceDue > 0)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _pay(context, quotation, 'advance'),
                        icon: const Icon(Icons.payments_outlined),
                        label: Text('Pay advance (${money(advanceDue)})'),
                      ),
                    ),
                  if (!pendingPayment &&
                      options.contains('full') &&
                      remaining > 0) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _pay(context, quotation, 'full'),
                        icon: const Icon(Icons.lock_outline),
                        label: Text('Pay balance (${money(remaining)})'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Orders List ───────────────────────────────────────────────────────────────
class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.statusColor,
    required this.api,
    required this.onRefresh,
  });
  final List<dynamic> orders;
  final Color Function(String) statusColor;
  final ApiClient api;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyState(
        icon: Icons.shopping_bag_outlined,
        label: 'No orders yet.\nPlace your first sign board order!',
      );
    }
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.navyDark,
      onRefresh: onRefresh, // ✅ already async Future<void>
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final o      = orders[i] as Map<String, dynamic>;
          final status = o['status']?.toString() ?? 'pending';
          final color  = statusColor(status);
          return _OrderCard(o: o, color: color, api: api, onRefresh: onRefresh);
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.o, required this.color, required this.api, required this.onRefresh});
  final Map<String, dynamic> o;
  final Color color;
  final ApiClient api;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final status = o['status']?.toString() ?? 'pending';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyLight),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(api: api, orderId: o['id'].toString())),
        ).then((_) => onRefresh()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_outlined, color: AppColors.gold, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o['id']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold, fontSize: 13)),
                Text(o['product']?.toString() ?? 'Sign Board',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.white)),
              ])),
              _Badge(humanize(status), color),
            ]),
            const Divider(height: 18, color: AppColors.navyLight),
            Row(children: [
              _Detail(Icons.straighten, '${o['length'] ?? 0}×${o['width'] ?? 0} ft'),
              const SizedBox(width: 16),
              _Detail(Icons.layers_outlined, o['material']?.toString() ?? ''),
              const Spacer(),
              Text(money(o['estimatedPrice']),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.gold)),
            ]),
            if ((o['createdAt'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Placed: ${o['createdAt']}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Services List ─────────────────────────────────────────────────────────────
class _ServicesList extends StatelessWidget {
  const _ServicesList({
    required this.services,
    required this.statusColor,
    required this.onRefresh,
  });
  final List<dynamic> services;
  final Color Function(String) statusColor;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const _EmptyState(
        icon: Icons.build_outlined,
        label: 'No service requests yet.\nTap Service tab to report an issue!',
      );
    }
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.navyDark,
      onRefresh: onRefresh, // ✅ already async Future<void>
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final s        = services[i] as Map<String, dynamic>;
          final status   = s['status']?.toString() ?? 'pending';
          final color    = statusColor(status);
          final priority = s['priority']?.toString() ?? 'normal';
          return _ServiceCard(s: s, color: color, priority: priority, onTap: () => _showDetail(context, s));
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navyDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.navyLight, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(s['id']?.toString() ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold)),
            const SizedBox(height: 4),
            Text(s['category']?.toString() ?? '',
                style: const TextStyle(color: AppColors.textLight)),
            const SizedBox(height: 14),
            Text(s['description']?.toString() ?? '',
                style: const TextStyle(color: AppColors.white, height: 1.5)),
            if ((s['statusHistory'] as List? ?? []).isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Status History',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.white)),
              const SizedBox(height: 10),
              ...(s['statusHistory'] as List).map((h) {
                final m = h as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    const Icon(Icons.history, size: 16, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Expanded(child: Text(humanize(m['status'] ?? ''),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.white))),
                    Text(m['time'] ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ]),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.s, required this.color, required this.priority, required this.onTap});
  final Map<String, dynamic> s;
  final Color color;
  final String priority;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = s['status']?.toString() ?? 'pending';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyLight),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.build_outlined, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['id']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent, fontSize: 13)),
                Text(s['category']?.toString() ?? 'Service',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.white)),
              ])),
              if (priority == 'emergency' || priority == 'high')
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Badge(humanize(priority), AppColors.danger),
                ),
              _Badge(humanize(status), color),
            ]),
            const Divider(height: 18, color: AppColors.navyLight),
            Text(s['description']?.toString() ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                s['technicianName'] != null
                    ? 'Tech: ${s['technicianName']}'
                    : 'Not assigned yet',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const Spacer(),
              Text(s['createdAt']?.toString() ?? '',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

class _Detail extends StatelessWidget {
  const _Detail(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: AppColors.textMuted),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
  ]);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 64, color: AppColors.navyLight),
      const SizedBox(height: 14),
      Text(label,
          style: const TextStyle(color: AppColors.textMuted, height: 1.5),
          textAlign: TextAlign.center),
    ]),
  );
}
