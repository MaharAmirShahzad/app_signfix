import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/app_utils.dart';
import '../../services/api_client.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<Map<String, dynamic>> _walletFuture;

  @override
  void initState() {
    super.initState();
    _walletFuture = widget.api.wallet();
  }

  Future<void> _refresh() async {
    final future = widget.api.wallet();
    setState(() => _walletFuture = future);
    await future.then<void>((_) {}, onError: (Object _) {});
  }

  double _amount(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String _date(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null
        ? 'Date unavailable'
        : DateFormat('dd MMM yyyy, h:mm a').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.navyDeep,
        appBar: AppBar(
          title: const Text('My Wallet'),
          backgroundColor: AppColors.navyDark,
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _walletFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 42),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load your wallet.',
                        style: TextStyle(color: AppColors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final wallet = snapshot.data ?? const <String, dynamic>{};
            final transactions = wallet['transactions'] is List
                ? wallet['transactions'] as List
                : const [];
            return RefreshIndicator(
              color: AppColors.gold,
              backgroundColor: AppColors.navyDark,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.navyLight, AppColors.navyDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: .5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                color: AppColors.gold),
                            SizedBox(width: 8),
                            Text('Available Balance',
                                style: TextStyle(color: AppColors.textLight)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          money(_amount(wallet['balance'])),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.savings_outlined,
                                color: AppColors.success, size: 19),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('Total Cashback Earned',
                                  style: TextStyle(color: AppColors.textLight)),
                            ),
                            Text(
                              money(_amount(wallet['totalCashbackEarned'])),
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: .3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: .15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.campaign_outlined,
                              color: AppColors.gold, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹200 Promotional Cashback Offer',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Order from our 3 eligible promotional banners to earn ₹200 cashback per qualifying order. Use your wallet balance at checkout for instant discounts!',
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Wallet Transaction History',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (transactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.navyDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.navyLight),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              color: AppColors.textMuted, size: 40),
                          SizedBox(height: 12),
                          Text(
                            'No transactions yet.',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Place an order using any of our 3 promotional banners to earn ₹200 cashback directly in your wallet!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...transactions.whereType<Map>().map(
                          (transaction) => _transactionCard(transaction),
                        ),
                ],
              ),
            );
          },
        ),
      );

  Widget _transactionCard(Map transaction) {
    final type = transaction['type']?.toString() ?? '';
    final isCredit = type == 'cashback_credit' ||
        type == 'wallet_refund' ||
        (type == 'admin_adjustment' &&
            _amount(transaction['balanceAfter']) >=
                _amount(transaction['previousBalance']));
    final amount = _amount(transaction['amount']);
    final color = isCredit ? AppColors.success : AppColors.warning;
    final status = (transaction['status']?.toString() ?? 'successful').toLowerCase();
    final statusColor = status == 'successful'
        ? AppColors.success
        : status == 'reversed'
            ? AppColors.danger
            : AppColors.warning;

    String title = transaction['description']?.toString().trim() ?? '';
    if (title.isEmpty) {
      if (type == 'cashback_credit') {
        title = 'Cashback Received';
      } else if (type == 'wallet_debit') {
        title = 'Wallet Used for Order';
      } else if (type == 'wallet_refund') {
        title = 'Wallet Refund';
      } else {
        title = isCredit ? 'Wallet Credit' : 'Wallet Debit';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navyDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCredit
              ? AppColors.success.withValues(alpha: .25)
              : AppColors.navyLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: .14),
                child: Icon(
                  isCredit
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _date(transaction['createdAt']),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? '+' : '-'}${money(amount)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: .35),
                      ),
                    ),
                    child: Text(
                      humanize(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 22, color: AppColors.navyLight),
          Wrap(
            spacing: 14,
            runSpacing: 7,
            children: [
              _detail('Transaction Type', isCredit ? 'Credit' : 'Debit'),
              _detail(
                'Previous Balance',
                money(_amount(transaction['previousBalance'])),
              ),
              _detail(
                'Remaining Balance',
                money(_amount(transaction['balanceAfter'])),
              ),
              if (transaction['orderNo'] != null)
                _detail('Order ID', transaction['orderNo'].toString()),
              if (transaction['transactionId'] != null)
                _detail(
                  'Transaction ID',
                  '#${transaction['transactionId']}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.navyDeep.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}
