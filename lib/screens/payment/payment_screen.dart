import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PaymentScreen — Full Razorpay checkout with dark SignFix theme
//  Usage:
//    Navigator.push(context, MaterialPageRoute(
//      builder: (_) => PaymentScreen(
//        api:          apiClient,
//        orderId:      'ORD-1001',
//      quotationNo:  'QUO-1001',
//      paymentType:  'full',
//      amount:       18500,   // in INR (not paise)
//        customerName: 'Ali Raza',
//        customerEmail:'ali@example.com',
//        customerPhone:'9876543210',
//        description:  'LED Sign Board 10×3 ft',
//        onSuccess: (paymentId) { ... },
//        onFailure: (reason)    { ... },
//      ),
//    ));
// ─────────────────────────────────────────────────────────────────────────────

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.api,
    required this.orderId,
    required this.quotationNo,
    required this.paymentType,
    required this.amount,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.description,
    required this.onSuccess,
    required this.onFailure,
  });

  final ApiClient api;
  final String orderId;
  final String quotationNo;
  final String paymentType;
  final double amount; // INR
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String description;
  final void Function(String paymentId) onSuccess;
  final void Function(String reason) onFailure;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final Razorpay _razorpay;
  bool _launched = false;
  bool _processing = false;
  String? _resultMessage;
  bool _isSuccess = false;
  bool _isPending = false;
  bool _canRetry = true;
  String? _paymentIntentId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _launch() async {
    setState(() {
      _launched = true;
      _processing = true;
      _isPending = false;
      _paymentIntentId = null;
    });

    try {
      final intent = await widget.api.createPaymentIntent({
        'quotationNo': widget.quotationNo,
        'type': widget.paymentType,
        'idempotencyKey':
            '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32).toRadixString(16)}',
      });
      final paymentIntentId = intent['id']?.toString();
      final checkoutValue = intent['checkout'];
      if (paymentIntentId == null ||
          paymentIntentId.isEmpty ||
          checkoutValue is! Map) {
        throw const ApiException(
          'The server did not return a valid Razorpay payment intent.',
        );
      }
      final checkout = Map<String, dynamic>.from(checkoutValue);
      final keyId = checkout['keyId']?.toString();
      final providerOrderId = checkout['orderId']?.toString();
      final checkoutAmount = checkout['amount'];
      final currency = checkout['currency']?.toString();
      if (keyId == null ||
          keyId.isEmpty ||
          providerOrderId == null ||
          providerOrderId.isEmpty ||
          checkoutAmount is! num ||
          checkoutAmount <= 0 ||
          currency == null ||
          currency.isEmpty) {
        throw const ApiException(
          'The server returned incomplete Razorpay checkout details.',
        );
      }
      _paymentIntentId = paymentIntentId;

      _razorpay.open({
        'key': keyId,
        'amount': checkoutAmount,
        'currency': currency,
        'name': checkout['name']?.toString() ?? 'SignFix',
        'description':
            checkout['description']?.toString() ?? widget.description,
        'order_id': providerOrderId,
        'prefill': {
          'name': widget.customerName,
          'email': widget.customerEmail,
          'contact': widget.customerPhone,
        },
        'theme': {
          'color': '#F5A623',
          'backdrop_color': '#0D1B4B',
        },
        'notes': {
          'signfix_quotation_no': widget.quotationNo,
          'signfix_order_no': widget.orderId,
        },
        'retry': {'enabled': true, 'max_count': 3},
        'send_sms_hash': true,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _resultMessage = e.toString();
        _isSuccess = false;
        _isPending = false;
        _canRetry = true;
      });
    }
  }

  void _onSuccess(PaymentSuccessResponse resp) {
    unawaited(_verifyAndComplete(resp));
  }

  Future<void> _verifyAndComplete(PaymentSuccessResponse resp) async {
    final paymentIntentId = _paymentIntentId;
    final paymentId = resp.paymentId;
    final providerOrderId = resp.orderId;
    final signature = resp.signature;
    if (paymentIntentId == null ||
        paymentId == null ||
        providerOrderId == null ||
        signature == null) {
      _showPending(
        'Razorpay returned incomplete payment details. Do not pay again yet; check your payment status or contact support.',
      );
      return;
    }

    setState(() {
      _processing = true;
      _resultMessage = null;
      _canRetry = false;
    });
    try {
      final verified = await widget.api.verifyPayment(paymentIntentId, {
        'razorpayPaymentId': paymentId,
        'razorpayOrderId': providerOrderId,
        'razorpaySignature': signature,
      });
      if (verified['status']?.toString() != 'captured') {
        _showPending(
          'Razorpay received your payment, but SignFix has not confirmed it yet. Do not pay again; check your payment status or contact support.',
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _processing = false;
        _isSuccess = true;
        _isPending = false;
        _resultMessage = paymentId;
      });
      widget.onSuccess(paymentId);
    } catch (e) {
      _showPending(
        'Razorpay returned your payment, but SignFix could not verify it: $e. Do not pay again; check your payment status or contact support.',
      );
    }
  }

  void _showPending(String message) {
    if (!mounted) return;
    setState(() {
      _processing = false;
      _isSuccess = false;
      _isPending = true;
      _canRetry = false;
      _resultMessage = message;
    });
  }

  void _onError(PaymentFailureResponse resp) {
    unawaited(_reportFailure(resp));
  }

  Future<void> _reportFailure(PaymentFailureResponse resp) async {
    final paymentIntentId = _paymentIntentId;
    var message = resp.message ?? 'Payment failed. Please try again.';
    if (paymentIntentId != null) {
      try {
        await widget.api.reportPaymentFailure(paymentIntentId, {
          if (resp.code != null) 'code': resp.code.toString(),
          'description': resp.message ?? 'Razorpay payment failed',
          'source': 'razorpay',
          'step': 'checkout',
        });
      } catch (e) {
        message = '$message SignFix could not update the payment status: $e';
      }
    }
    if (!mounted) return;
    setState(() {
      _processing = false;
      _isSuccess = false;
      _isPending = false;
      _canRetry = true;
      _resultMessage = message;
    });
    widget.onFailure(message);
  }

  void _onWallet(ExternalWalletResponse resp) {
    _showPending(
      'The ${resp.walletName} payment was started, but has not been confirmed by SignFix yet. Check your payment status before trying again.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.navyDeep,
        appBar: AppBar(
          backgroundColor: AppColors.navyDark,
          title: const Row(children: [
            Icon(Icons.payment_rounded, color: AppColors.gold, size: 22),
            SizedBox(width: 8),
            Text('Secure Payment',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.white)),
          ]),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.gold),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _resultMessage != null
            ? _ResultView(
                isSuccess: _isSuccess,
                isPending: _isPending,
                message: _resultMessage!,
                orderId: widget.orderId,
                onDone: () => Navigator.pop(context, _isSuccess),
                onRetry: !_canRetry || _isSuccess
                    ? null
                    : () => setState(() {
                          _resultMessage = null;
                          _launched = false;
                          _isPending = false;
                          _paymentIntentId = null;
                        }),
              )
            : _processing
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(color: AppColors.gold),
                      SizedBox(height: 16),
                      Text('Opening payment gateway…',
                          style: TextStyle(color: AppColors.textLight)),
                    ]),
                  )
                : _PaymentSummary(
                    orderId: widget.orderId,
                    paymentType: widget.paymentType,
                    amount: widget.amount,
                    description: widget.description,
                    customerName: widget.customerName,
                    onPay: () {
                      _launch();
                    },
                    launched: _launched,
                  ),
      );
}

// ── Payment Summary Page ──────────────────────────────────────────────────────
class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({
    required this.orderId,
    required this.paymentType,
    required this.amount,
    required this.description,
    required this.customerName,
    required this.onPay,
    required this.launched,
  });
  final String orderId, paymentType, description, customerName;
  final double amount;
  final VoidCallback onPay;
  final bool launched;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Payment header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2E7A), Color(0xFF0F1E55)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gold.withValues(alpha: .3)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: AppColors.gold, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Approved quotation',
                          style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      Text(orderId,
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ])),
              ]),
              const SizedBox(height: 16),
              Divider(color: AppColors.navyLight.withValues(alpha: .6)),
              const SizedBox(height: 12),
              _SummaryRow('Customer', customerName),
              _SummaryRow('Payment option',
                  paymentType == 'advance' ? '25% advance' : 'Full balance'),
              _SummaryRow('Description', description),
              const SizedBox(height: 12),
              Divider(color: AppColors.navyLight.withValues(alpha: .6)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Final quotation amount',
                    style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 26,
                      fontWeight: FontWeight.w900),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Payment methods info ─────────────────────────────────────────────
          const Text('Accepted Payment Methods',
              style: TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 12),
          const Row(children: [
            _PayMethod(Icons.account_balance_wallet_outlined, 'UPI / GPay',
                AppColors.gold),
            SizedBox(width: 10),
            _PayMethod(
                Icons.credit_card_outlined, 'Credit / Debit', AppColors.info),
            SizedBox(width: 10),
            _PayMethod(Icons.account_balance_outlined, 'Net Banking',
                AppColors.success),
          ]),
          const SizedBox(height: 12),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _PayMethod(
                Icons.phone_android_outlined, 'Wallets', AppColors.warning),
            SizedBox(width: 10),
            _PayMethod(
                Icons.currency_rupee_outlined, 'EMI', AppColors.textLight),
          ]),
          const SizedBox(height: 28),

          // ── Security badge ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navyDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.navyLight),
            ),
            child: const Row(children: [
              Icon(Icons.lock_rounded, color: AppColors.success, size: 18),
              SizedBox(width: 10),
              Expanded(
                  child: Text(
                '100% Secure • Powered by Razorpay • PCI DSS Compliant',
                style: TextStyle(color: AppColors.textLight, fontSize: 12),
              )),
            ]),
          ),
          const SizedBox(height: 28),

          // ── Pay button ────────────────────────────────────────────────────────
          GestureDetector(
            onTap: launched ? null : onPay,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gold, AppColors.goldDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: .35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.lock_rounded,
                    color: AppColors.navyDeep, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Pay ₹${amount.toStringAsFixed(0)} Securely',
                  style: const TextStyle(
                    color: AppColors.navyDeep,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'You will be redirected to Razorpay secure checkout',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
}

// ── Result View ───────────────────────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.isSuccess,
    required this.isPending,
    required this.message,
    required this.orderId,
    required this.onDone,
    required this.onRetry,
  });
  final bool isSuccess;
  final bool isPending;
  final String message, orderId;
  final VoidCallback onDone;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final statusColor = isSuccess
        ? AppColors.success
        : isPending
            ? AppColors.warning
            : AppColors.danger;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .12),
              shape: BoxShape.circle,
              border: Border.all(color: statusColor, width: 2),
            ),
            child: Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : isPending
                      ? Icons.hourglass_top_rounded
                      : Icons.cancel_rounded,
              color: statusColor,
              size: 52,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            isSuccess
                ? 'Payment Successful!'
                : isPending
                    ? 'Payment Status Pending'
                    : 'Payment Failed',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isSuccess
                  ? AppColors.success
                  : isPending
                      ? AppColors.warning
                      : AppColors.danger,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.navyDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.navyLight),
            ),
            child: Text(
              isSuccess ? 'Payment ID: $message' : message,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          if (isSuccess) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: .3)),
              ),
              child: Text(
                'Payment recorded for order $orderId',
                style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDone,
              child: Text(isSuccess ? 'View My Orders' : 'Back to Order'),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Flexible(
              child: Text(value,
                  style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.end)),
        ]),
      );
}

class _PayMethod extends StatelessWidget {
  const _PayMethod(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.navyDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: .3)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}
