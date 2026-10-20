import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/app_theme.dart';
import '../../core/app_utils.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import 'text_designer_screen.dart';

class OrderWizard extends StatefulWidget {
  const OrderWizard({super.key, required this.api});
  final ApiClient api;
  @override
  State<OrderWizard> createState() => _OrderWizardState();
}

class _OrderWizardState extends State<OrderWizard> {
  int step = 0;
  String type = 'LED Sign Board', material = 'Acrylic', lighting = 'LED';
  final length = TextEditingController(text: '10');
  final width = TextEditingController(text: '3');
  final quantity = TextEditingController(text: '1');
  final address = TextEditingController();
  bool installation = true, transportation = true, loading = false;
  Map<String, dynamic>? quote;
  SignBoardTextDesign? _textDesign;

  // Address autocomplete
  List<Map<String, dynamic>> _suggestions = [];
  bool _loadingSuggestions = false;
  Timer? _debounce;
  final _addressFocus = FocusNode();
  bool _showSuggestions = false;

  // ── Step 4 Payment state ──────────────────────────────────────────────────
  late final Razorpay _razorpay;
  bool   _payProcessing  = false;
  bool   _payLaunched    = false;
  String? _payIntentId;
  String? _payError;
  bool   _payPending     = false;
  bool   _paySuccess     = false;
  String _payMethod      = 'upi';
  String _ledWatt = '10W';
  String? _sideWalling;
  final  _upiController  = TextEditingController();
  String? _upiError;
  Map<String, dynamic>? _customerProfile;
  static final _upiRegex =
      RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,}$');

  // Payment type
  String _paymentType = 'full';

  // Auto-generated quotationNo from backend after order creation
  String _autoQuotationNo = '';

  // Card payment controllers
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl     = TextEditingController();
  final _cvvCtrl        = TextEditingController();
  final _cardNameCtrl   = TextEditingController();

  // Net banking
  String? _selectedBank;

  // Wallets
  String? _selectedWallet;

  // EMI
  int? _emiMonths;

  // 5 steps: 0-TextDesign · 1-Type · 2-Dimensions · 3-Finish · 4-Estimate
  static const _totalSteps = 5;

  static const _types = [
    'LED Sign Board',
    'Acrylic Sign Board',
    'Flex Sign Board',
    'Glow Sign Board',
    '3D Letter',
    'Channel Letter',
    'Neon Sign',
    'Backlit Sign',
    'Outdoor Signage',
    'Custom Sign Board',
    'Module LED Letters',
    'Channel LED Letters',
    'Bata Type LED Letters',
  ];
  static const _materials = [
    'Acrylic',
    'ACP',
    'PVC',
    'Flex',
    'Stainless Steel',
    'Aluminium'
  ];
  static const _lightings = [
    'No Lighting',
    'LED',
    'Backlit',
    'Neon',
    'Front Lit',
    'Custom'
  ];
  static const _wattOptions = [
    '5W', '10W', '12W', '15W', '18W', '20W', '24W', '30W', '40W', '50W'
  ];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onPayWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _upiController.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _cardNameCtrl.dispose();
    for (final c in [length, width, quantity, address]) {
      c.dispose();
    }
    _debounce?.cancel();
    _addressFocus.dispose();
    super.dispose();
  }

  void _err(Object e) => showAppError(context, e);

  // ── Address Autocomplete (Nominatim / OpenStreetMap) ──────────────────────
  void _onAddressChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
      return;
    }
    _debounce = Timer(
        const Duration(milliseconds: 600), () => _fetchSuggestions(value));
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!mounted) return;
    setState(() => _loadingSuggestions = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&addressdetails=1&limit=5&countrycodes=in',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'SignFix/1.0 (signfix@app.com)'
      }).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _suggestions =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    } catch (_) {
      // silently ignore network errors — user can still type manually
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  void _selectSuggestion(Map<String, dynamic> place) {
    final display = place['display_name']?.toString() ?? '';
    address.text = display;
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
    _addressFocus.unfocus();
  }

  // Map new sign types to existing backend product names
  // New types (Module/Channel/Bata) map to 'LED Sign Board' in DB
  // until admin adds them to the products catalog
  String get _backendProductName {
    const mapping = {
      'Module LED Letters':   'LED Sign Board',
      'Channel LED Letters':  'LED Sign Board',
      'Bata Type LED Letters':'LED Sign Board',
    };
    return mapping[type] ?? type;
  }

  Future<void> _calculate() async {
    final l = double.tryParse(length.text);
    final w = double.tryParse(width.text);
    final q = int.tryParse(quantity.text);
    if (l == null || w == null || q == null || l <= 0 || w <= 0 || q <= 0) {
      _err('Enter valid dimensions and quantity.');
      return;
    }
    if (address.text.trim().isEmpty) {
      _err('Please enter the delivery / installation address.');
      return;
    }
    setState(() => loading = true);
    try {
      quote = await widget.api.calculate({
        'product': _backendProductName,
        'length': l,
        'width': w,
        'quantity': q,
        'material': material,
        'lighting': lighting,
        'installation': installation,
        'transportation': transportation,
        'ledWatt': _ledWatt,
        if (_textDesign != null) 'signText': _textDesign!.text,
        if (_textDesign != null) 'signFont': _textDesign!.fontFamily,
      });
      setState(() => step = 4);
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _submitOrder() async {
    if (quote == null) return;
    setState(() => loading = true);
    try {
      final order = await widget.api.createOrder({
        'product': _backendProductName,
        'length': double.parse(length.text),
        'width': double.parse(width.text),
        'quantity': int.parse(quantity.text),
        'material': material,
        'lighting': lighting,
        'installation': installation,
        'transportation': transportation,
        'address': address.text.trim(),
        'estimatedPrice': quote!['estimatedPrice'],
        'ledWatt': _ledWatt,
        if (_sideWalling != null) 'sideWalling': _sideWalling!,
        if (_textDesign != null) 'signText': _textDesign!.text,
        if (_textDesign != null) 'signFont': _textDesign!.fontFamily,
        if (_textDesign != null)
          'signColor': _textDesign!.color.toARGB32().toRadixString(16),
      });
      final id = order['id']?.toString();
      // Save quotationNo returned by backend (auto-created with order)
      final quotationNo = order['quotationNo']?.toString() ?? '';
      if (id == null || id.isEmpty) {
        throw const ApiException(
          'The server did not return the new order number.',
        );
      }
      // Store quotationNo for payment intent
      setState(() => _autoQuotationNo = quotationNo);
      if (mounted) {
        await showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  backgroundColor: AppColors.navyDark,
                  icon: const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 48),
                  title: const Text('Order Saved',
                      style: TextStyle(color: AppColors.white)),
                  content: Text(
                      '$id submitted for admin review. Your payment has been recorded.',
                      style: const TextStyle(color: AppColors.textLight),
                      textAlign: TextAlign.center),
                  actions: [
                    FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _reset();
                        },
                        child: const Text('OK'))
                  ],
                ));
      }
    } catch (e) {
      if (mounted) _err(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _reset() => setState(() {
        step = 0;
        quote = null;
        _textDesign = null;
        _payProcessing = false;
        _payLaunched   = false;
        _payIntentId   = null;
        _payError      = null;
        _payPending    = false;
        _paySuccess    = false;
        _upiController.clear();
        _upiError      = null;
        _customerProfile = null;
        _ledWatt = '10W';
        _sideWalling = null;
        _paymentType = 'full';
        _autoQuotationNo = '';
        _cardNumberCtrl.clear();
        _expiryCtrl.clear();
        _cvvCtrl.clear();
        _cardNameCtrl.clear();
        _selectedBank = null;
        _selectedWallet = null;
        _emiMonths = null;
      });

  // ── Payment methods ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getProfile() async {
    _customerProfile ??= await widget.api.getProfile();
    return _customerProfile!;
  }

  Future<void> _payAndSubmit() async {
    if (_payLaunched || _payProcessing) return;

    // Validate based on selected payment method
    if (_payMethod == 'upi') {
      final upiId = _upiController.text.trim();
      if (upiId.isNotEmpty && !_upiRegex.hasMatch(upiId)) {
        setState(() => _upiError = 'Enter a valid UPI ID (e.g. username@bank)');
        return;
      }
    } else if (_payMethod == 'card') {
      final cardNum = _cardNumberCtrl.text.replaceAll(' ', '');
      final expiry  = _expiryCtrl.text.trim();
      final cvv     = _cvvCtrl.text.trim();
      final name    = _cardNameCtrl.text.trim();
      if (cardNum.length != 16 || !RegExp(r'^[0-9]{16}$').hasMatch(cardNum)) {
        setState(() => _payError = 'Enter a valid 16-digit card number.');
        return;
      }
      if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(expiry)) {
        setState(() => _payError = 'Enter expiry as MM/YY.');
        return;
      }
      if (cvv.length != 3 || !RegExp(r'^[0-9]{3}$').hasMatch(cvv)) {
        setState(() => _payError = 'Enter a valid 3-digit CVV.');
        return;
      }
      if (name.isEmpty) {
        setState(() => _payError = 'Enter the cardholder name.');
        return;
      }
    } else if (_payMethod == 'netbanking') {
      if (_selectedBank == null) {
        setState(() => _payError = 'Please select a bank.');
        return;
      }
    } else if (_payMethod == 'wallet') {
      if (_selectedWallet == null) {
        setState(() => _payError = 'Please select a wallet.');
        return;
      }
    } else if (_payMethod == 'emi') {
      if (_emiMonths == null) {
        setState(() => _payError = 'Please select an EMI plan.');
        return;
      }
    }

    if (_upiError != null) setState(() => _upiError = null);

    setState(() {
      _payProcessing = true;
      _payLaunched   = false;
      _payIntentId   = null;
      _payError      = null;
      _payPending    = false;
      _paySuccess    = false;
    });

    try {
      final profile = await _getProfile();
      final estimatedPrice =
          (quote!['estimatedPrice'] as num?)?.toDouble() ?? 0;
      final payAmount =
          _paymentType == 'advance' ? estimatedPrice * 0.25 : estimatedPrice;

      // ── Step 1: Create order first if not done yet ───────────────────────
      // Order must exist before payment intent — backend auto-creates quotation
      if (_autoQuotationNo.isEmpty) {
        await _submitOrder();
        // If submitOrder failed or quotationNo still empty, stop
        if (_autoQuotationNo.isEmpty) {
          setState(() {
            _payProcessing = false;
            _payError = 'Could not create order. Please try again.';
          });
          return;
        }
      }

      // ── Step 2: Create payment intent with the real quotationNo ──────────
      final intent = await widget.api.createPaymentIntent({
        'quotationNo': _autoQuotationNo,
        'type': _paymentType,
        'amount': payAmount,
        'idempotencyKey':
            '${DateTime.now().microsecondsSinceEpoch}-'
            '${Random.secure().nextInt(1 << 32).toRadixString(16)}',
      });

      final intentId       = intent['id']?.toString();
      final checkoutValue  = intent['checkout'];
      if (intentId == null || intentId.isEmpty || checkoutValue is! Map) {
        throw const ApiException(
          'The server did not return a valid payment intent.',
        );
      }
      final checkout        = Map<String, dynamic>.from(checkoutValue);
      final keyId           = checkout['keyId']?.toString();
      final providerOrderId = checkout['orderId']?.toString();
      final checkoutAmount  = checkout['amount'];
      final currency        = checkout['currency']?.toString();
      if (keyId == null || keyId.isEmpty ||
          providerOrderId == null || providerOrderId.isEmpty ||
          checkoutAmount is! num || checkoutAmount <= 0 ||
          currency == null || currency.isEmpty) {
        throw const ApiException(
          'The server returned incomplete Razorpay checkout details.',
        );
      }

      _payIntentId = intentId;

      final upiId = _upiController.text.trim();

      // ── FIX: Razorpay expects method as a STRING, not a Map ──────────────
      // Wrong:  'method': {'upi': 1}   ← SDK ignores this silently
      // Correct:'method': 'upi'        ← SDK pre-selects and deep-links
      final String? razorpayMethod = switch (_payMethod) {
        'upi'        => 'upi',
        'card'       => 'card',
        'netbanking' => 'netbanking',
        'wallet'     => 'wallet',
        'emi'        => 'emi',
        _            => null,
      };

      // ── Wallet name → Razorpay wallet code mapping ────────────────────────
      // Razorpay wallet codes: 'paytm', 'phonepe', 'googlepay', etc.
      final String? walletCode = switch (_selectedWallet) {
        'GPay'     => 'googlepay',
        'PhonePe'  => 'phonepe',
        'Paytm'    => 'paytm',
        _          => null,
      };

      // ── Bank name → Razorpay bank code mapping ────────────────────────────
      // Razorpay netbanking bank codes (IFSC-style short codes)
      final String? bankCode = switch (_selectedBank) {
        'SBI'                   => 'SBIN',
        'HDFC Bank'             => 'HDFC',
        'ICICI Bank'            => 'ICIC',
        'Axis Bank'             => 'UTIB',
        'Kotak Mahindra'        => 'KKBK',
        'Punjab National Bank'  => 'PUNB',
        'Bank of Baroda'        => 'BARB',
        'Canara Bank'           => 'CNRB',
        'Yes Bank'              => 'YESB',
        'IDBI Bank'             => 'IBKL',
        _                       => null,
      };

      _razorpay.open({
        'key':         keyId,
        'amount':      checkoutAmount,
        'currency':    currency,
        'name':        checkout['name']?.toString() ?? 'SignFix',
        'description': checkout['description']?.toString() ?? type,
        'order_id':    providerOrderId,
        'prefill': {
          'name':    profile['name']?.toString() ?? '',
          'email':   profile['email']?.toString() ?? '',
          'contact': profile['phone']?.toString() ?? profile['mobile']?.toString() ?? '',
          // Prefill UPI VPA only when UPI is selected and user has entered an ID
          if (_payMethod == 'upi' && upiId.isNotEmpty) 'vpa': upiId,
          // Prefill bank code for net banking — guides Razorpay to correct bank page
          if (_payMethod == 'netbanking' && bankCode != null) 'bank': bankCode,
          // Prefill wallet code for wallet payments — triggers deep-link
          if (_payMethod == 'wallet' && walletCode != null) 'wallet': walletCode,
        },
        // Pass method as STRING — this is the key fix
        // Razorpay SDK uses this to pre-select the tab & trigger deep-links
        if (razorpayMethod != null) 'method': razorpayMethod,
        'theme': {
          'color':          '#F5A623',
          'backdrop_color': '#0D1B4B',
        },
        'notes': {
          'signfix_order_wizard': 'true',
        },
        'retry': {'enabled': true, 'max_count': 3},
        'send_sms_hash': true,
      });

      setState(() {
        _payLaunched   = true;
        _payProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _payProcessing = false;
        _payError      = e.toString();
      });
    }
  }

  void _onPaySuccess(PaymentSuccessResponse resp) {
    unawaited(_verifyAndSubmit(resp));
  }

  Future<void> _verifyAndSubmit(PaymentSuccessResponse resp) async {
    final intentId        = _payIntentId;
    final paymentId       = resp.paymentId;
    final providerOrderId = resp.orderId;
    final signature       = resp.signature;
    if (intentId == null || paymentId == null ||
        providerOrderId == null || signature == null) {
      _setPayPending(
        'Razorpay returned incomplete payment details. '
        'Do not pay again — check your payment status or contact support.',
      );
      return;
    }
    setState(() {
      _payProcessing = true;
      _payError      = null;
    });
    try {
      final verified = await widget.api.verifyPayment(intentId, {
        'razorpayPaymentId': paymentId,
        'razorpayOrderId':   providerOrderId,
        'razorpaySignature': signature,
      });
      if (verified['status']?.toString() != 'captured') {
        _setPayPending(
          'Razorpay received your payment, but SignFix has not confirmed '
          'it yet. Do not pay again; check your status or contact support.',
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _payProcessing = false;
        _paySuccess    = true;
        _payPending    = false;
        _payError      = null;
      });
      // Order already created before payment — just show success dialog
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.navyDark,
            icon: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 48),
            title: const Text('Payment Successful!',
                style: TextStyle(color: AppColors.white)),
            content: Text(
              'Your payment was received and order $_autoQuotationNo is confirmed.\n\nAdmin will review and proceed with production.',
              style: const TextStyle(color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _reset();
                },
                child: const Text('View Orders'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _setPayPending(
        'Payment was received but could not be verified: $e. '
        'Do not pay again; check your payment status or contact support.',
      );
    }
  }

  void _onPayError(PaymentFailureResponse resp) {
    unawaited(_handlePayError(resp));
  }

  Future<void> _handlePayError(PaymentFailureResponse resp) async {
    final intentId = _payIntentId;
    final message  = _friendlyPayError(resp);
    if (intentId != null) {
      try {
        await widget.api.reportPaymentFailure(intentId, {
          if (resp.code != null) 'code': resp.code.toString(),
          'description': resp.message ?? 'Razorpay payment failed',
          'source': 'razorpay',
          'step':   'checkout',
        });
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _payProcessing = false;
      _payLaunched   = false;
      _payError      = message;
    });
  }

  String _friendlyPayError(PaymentFailureResponse resp) {
    final code = resp.code ?? 0;
    final raw  = (resp.message ?? '').toLowerCase();
    if (code == Razorpay.PAYMENT_CANCELLED ||
        raw.contains('cancel') || raw.contains('dismiss')) {
      return 'You cancelled the payment. You can try again whenever you\'re ready.';
    }
    if (code == Razorpay.NETWORK_ERROR ||
        raw.contains('network') || raw.contains('timeout') ||
        raw.contains('connect')) {
      return 'Unable to connect to the payment service. Please check your internet connection and try again.';
    }
    if (raw.contains('insufficient') || raw.contains('low balance')) {
      return 'Insufficient funds. Please try another payment method.';
    }
    if (raw.contains('declined') || raw.contains('do not honour')) {
      return 'Payment declined by your bank. Please try another method.';
    }
    final cleanMsg = resp.message
        ?.replaceAll(RegExp(r'Exception:?\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim() ?? '';
    if (cleanMsg.isNotEmpty && cleanMsg.length < 120) return cleanMsg;
    return 'Payment could not be completed. Please try a different payment method or contact support.';
  }

  void _onPayWallet(ExternalWalletResponse resp) {
    _setPayPending(
      'The ${resp.walletName} payment was started. '
      'Check your payment status before trying again.',
    );
  }

  void _setPayPending(String message) {
    if (!mounted) return;
    setState(() {
      _payProcessing = false;
      _payPending    = true;
      _payError      = message;
      _payLaunched   = false;
    });
  }

  // ── Step validation ──────────────────────────────────────────────────────
  bool _validateStep() {
    switch (step) {
      case 0:
        // Text designer step — optional, always allow next
        return true;
      case 1:
        // Sign type — already has default value, always valid
        return true;
      case 2:
        // Dimensions + address
        final l = double.tryParse(length.text);
        final w = double.tryParse(width.text);
        final q = int.tryParse(quantity.text);
        if (l == null || l <= 0) {
          _showValidationError('Please enter a valid length (ft).');
          return false;
        }
        if (w == null || w <= 0) {
          _showValidationError('Please enter a valid width (ft).');
          return false;
        }
        if (q == null || q <= 0) {
          _showValidationError('Please enter a valid quantity.');
          return false;
        }
        if (address.text.trim().isEmpty) {
          _showValidationError(
              'Please enter the delivery / installation address.');
          return false;
        }
        return true;
      case 3:
        // Finish & options — material/lighting already have defaults
        return true;
      default:
        return true;
    }
  }

  void _showValidationError(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _nextStep() {
    if (_validateStep()) setState(() => step++);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: Column(
        children: [
          // ── Scrollable content ─────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              children: _buildStepContent(),
            ),
          ),

          // ── Nav row — always pinned at bottom ──────────────────────────
          if (step < 4)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                color: Colors.transparent,
                child: Row(children: [
                  if (step > 0)
                    OutlinedButton.icon(
                      onPressed: loading ? null : () => setState(() => step--),
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(80, 48),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: 160,
                    child: LoadingButton(
                      loading: loading,
                      onPressed: step == 3 ? _calculate : _nextStep,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(step == 3 ? 'Get Quote' : 'Continue'),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),

          // ── Step 4 (Price Estimate) nav — Edit + Start Over ────────────
          if (step == 4)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                color: Colors.transparent,
                child: Row(children: [
                  // Edit details — go back to Step 3 (Finish & Options)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          loading ? null : () => setState(() => step = 3),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit Details'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Start over — reset wizard
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : _reset,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Start Over'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        side: const BorderSide(color: AppColors.navyLight),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ── Step content (returned as list for ListView) ──────────────────────────
  List<Widget> _buildStepContent() {
    return [
      // Progress bar
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withValues(alpha: .4)),
          ),
          child: Text(
            'Step ${step + 1} of $_totalSteps',
            style: const TextStyle(
                color: AppColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (step + 1) / _totalSteps,
              minHeight: 6,
              backgroundColor: AppColors.navyLight,
              color: AppColors.gold,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 22),

      // Step 0 — Text Designer
      if (step == 0) ..._step0(),
      // Step 1 — Sign Type
      if (step == 1) ..._step1(),
      // Step 2 — Dimensions
      if (step == 2) ..._step2(),
      // Step 3 — Finish
      if (step == 3) ..._step3(),
      // Step 4 — Quote + Pay
      if (step == 4 && quote != null) ..._step4(),

      const SizedBox(height: 16),
    ];
  }

  // ── Step 0: Text Designer ─────────────────────────────────────────────────
  List<Widget> _step0() => [
        _heading('Design Your Sign Text', Icons.text_fields_rounded),
        if (_textDesign != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF050A1A),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: _textDesign!.color.withValues(alpha: .4)),
              boxShadow: [
                BoxShadow(
                    color: _textDesign!.color.withValues(alpha: .2),
                    blurRadius: 16)
              ],
            ),
            child: Center(
              child: Text(
                _textDesign!.text,
                style: TextStyle(
                  fontFamily: _textDesign!.fontFamily,
                  fontSize: 28,
                  color: _textDesign!.color,
                  shadows: [
                    Shadow(
                        color: _textDesign!.color.withValues(alpha: .8),
                        blurRadius: 12),
                    Shadow(
                        color: _textDesign!.color.withValues(alpha: .4),
                        blurRadius: 24),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final r = await Navigator.push<SignBoardTextDesign>(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            TextDesignerScreen(initial: _textDesign)));
                if (r != null && mounted) setState(() => _textDesign = r);
              },
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit Text Design'),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.navyDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.navyLight),
            ),
            child: Column(children: [
              const Icon(Icons.text_fields_rounded,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text('Add your sign board text',
                  style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(height: 6),
              const Text('Choose font, color and preview the neon effect',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final r = await Navigator.push<SignBoardTextDesign>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TextDesignerScreen()));
                  if (r != null && mounted) setState(() => _textDesign = r);
                },
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Open Text Designer'),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => setState(() => step = 1),
              child: const Text('Skip — Choose sign type instead',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          ),
        ],
      ];

  // ── Step 1: Sign Type ─────────────────────────────────────────────────────
  List<Widget> _step1() => [
        _heading('Choose Sign Type', Icons.storefront_rounded),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _types
              .map((x) => ChoiceChip(
                    label: Text(x),
                    selected: type == x,
                    selectedColor: AppColors.gold.withValues(alpha: .2),
                    checkmarkColor: AppColors.gold,
                    onSelected: (_) => setState(() {
                      type = x;
                      _sideWalling = null;
                    }),
                  ))
              .toList(),
        ),
        if ((['Module LED Letters', 'Channel LED Letters', 'Bata Type LED Letters'].contains(type))) ...[
          const SizedBox(height: 16),
          const Text(
            'Side Walling Color',
            style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final options = switch (type) {
              'Module LED Letters'    => const ['Black', 'Grey'],
              'Channel LED Letters'   => const ['Gold', 'Silver', 'White', 'Black', 'Blue', 'Red'],
              'Bata Type LED Letters' => const ['Gold', 'Rose Gold', 'Silver'],
              _                       => const <String>[],
            };
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((opt) => ChoiceChip(
                label: Text(opt),
                selected: _sideWalling == opt,
                selectedColor: AppColors.gold.withValues(alpha: .2),
                checkmarkColor: AppColors.gold,
                onSelected: (_) => setState(() => _sideWalling = opt),
              )).toList(),
            );
          }),
        ],
      ];

  // ── Step 2: Dimensions ────────────────────────────────────────────────────
  List<Widget> _step2() => [
        _heading('Dimensions & Delivery', Icons.straighten_rounded),
        Row(children: [
          Expanded(
              child: TextField(
            controller: length,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.white),
            decoration: const InputDecoration(
                labelText: 'Length (ft)',
                prefixIcon: Icon(Icons.height_rounded)),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
            controller: width,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.white),
            decoration: const InputDecoration(
                labelText: 'Width (ft)',
                prefixIcon: Icon(Icons.expand_rounded)),
          )),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: quantity,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.white),
          decoration: const InputDecoration(
              labelText: 'Quantity',
              prefixIcon: Icon(Icons.format_list_numbered_rounded)),
        ),
        const SizedBox(height: 12),
        // ── Address field with autocomplete ──────────────────────────────────
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: address,
              focusNode: _addressFocus,
              maxLines: 2,
              style: const TextStyle(color: AppColors.white),
              onChanged: _onAddressChanged,
              onTap: () {
                if (address.text.trim().length >= 3) {
                  setState(() => _showSuggestions = _suggestions.isNotEmpty);
                }
              },
              decoration: InputDecoration(
                labelText: 'Delivery / installation address',
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: _loadingSuggestions
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.gold),
                        ),
                      )
                    : address.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                size: 18, color: AppColors.textMuted),
                            onPressed: () {
                              address.clear();
                              setState(() {
                                _suggestions = [];
                                _showSuggestions = false;
                              });
                            },
                          )
                        : null,
              ),
            ),
            // Suggestions dropdown
            if (_showSuggestions && _suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppColors.navyMid,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: .3)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: .3),
                        blurRadius: 8)
                  ],
                ),
                child: Column(
                  children: _suggestions.asMap().entries.map((entry) {
                    final i = entry.key;
                    final place = entry.value;
                    final name = place['display_name']?.toString() ?? '';
                    final parts = name.split(', ');
                    final title = parts.take(2).join(', ');
                    final subtitle = parts.skip(2).take(3).join(', ');
                    return Column(
                      children: [
                        InkWell(
                          onTap: () => _selectSuggestion(place),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(children: [
                              const Icon(Icons.place_outlined,
                                  color: AppColors.gold, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(title,
                                          style: const TextStyle(
                                              color: AppColors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      if (subtitle.isNotEmpty)
                                        Text(subtitle,
                                            style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                    ]),
                              ),
                            ]),
                          ),
                        ),
                        if (i < _suggestions.length - 1)
                          const Divider(
                              height: 0,
                              color: AppColors.navyLight,
                              indent: 42),
                      ],
                    );
                  }).toList(),
                ),
              ),
            if (_showSuggestions && _suggestions.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 4),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: 11, color: AppColors.textMuted),
                  SizedBox(width: 4),
                  Text('Powered by OpenStreetMap',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ]),
              ),
          ],
        ),
      ];

  // ── Step 3: Finish & Options ──────────────────────────────────────────────
  List<Widget> _step3() => [
        _heading('Finish & Options', Icons.palette_rounded),
        DropdownButtonFormField<String>(
          initialValue: material,
          decoration: const InputDecoration(labelText: 'Material'),
          dropdownColor: AppColors.navyMid,
          items: _materials
              .map((x) => DropdownMenuItem(value: x, child: Text(x)))
              .toList(),
          onChanged: (v) => setState(() => material = v!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: lighting,
          decoration: const InputDecoration(labelText: 'Lighting'),
          dropdownColor: AppColors.navyMid,
          items: _lightings
              .map((x) => DropdownMenuItem(value: x, child: Text(x)))
              .toList(),
          onChanged: (v) => setState(() => lighting = v!),
        ),
        const SizedBox(height: 12),
        if (lighting != 'No Lighting') ...[
          const SizedBox(height: 12),
          const Text(
            'LED Watt per Square Foot',
            style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _wattOptions.map((w) {
                final selected = _ledWatt == w;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(w),
                    selected: selected,
                    selectedColor: AppColors.gold.withValues(alpha: .2),
                    checkmarkColor: AppColors.gold,
                    onSelected: (_) => setState(() => _ledWatt = w),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final wattValue = double.tryParse(
                    _ledWatt.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 10.0;
            final l = double.tryParse(length.text) ?? 0;
            final ww = double.tryParse(width.text) ?? 0;
            final q = int.tryParse(quantity.text) ?? 1;
            final totalWatts = wattValue * l * ww * q;
            final monthlyCost = (totalWatts * 8 * 30 * 6.5 / 1000).round();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.navyDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: .3)),
              ),
              child: Row(children: [
                const Icon(Icons.bolt_rounded, color: AppColors.gold, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Estimated power: ~${totalWatts.toStringAsFixed(0)}W  |  Monthly cost: ~₹$monthlyCost',
                    style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                  ),
                ),
              ]),
            );
          }),
        ],
        Material(
          color: AppColors.navyDark,
          borderRadius: BorderRadius.circular(14),
          child: Column(children: [
            SwitchListTile(
              value: installation,
              onChanged: (v) => setState(() => installation = v),
              title: const Text('Installation required'),
              subtitle: const Text('+₹1,500'),
            ),
            const Divider(height: 0, color: AppColors.navyLight),
            SwitchListTile(
              value: transportation,
              onChanged: (v) => setState(() => transportation = v),
              title: const Text('Transportation required'),
              subtitle: const Text('+₹800'),
            ),
          ]),
        ),
      ];

  // ── Step 4: Quote + Payment ───────────────────────────────────────────────
  List<Widget> _step4() => [
        _heading('Price Estimate & Payment', Icons.calculate_rounded),

        // Breakdown
        Container(
          decoration: BoxDecoration(
            color: AppColors.navyDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.navyLight),
          ),
          child: Column(children: [
            ...[
              'productCost',
              'materialCost',
              'lightingCost',
              'wattCost',
              'installation',
              'transportation',
              'gst',
            ]
                .where((k) => (quote![k] ?? 0) > 0)
                .map(
                  (k) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Text(humanize(k),
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 13)),
                      const Spacer(),
                      Text(money(quote![k]),
                          style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ]),
                  ),
                )
                .expand((w) =>
                    [w, const Divider(height: 0, color: AppColors.navyLight)])
                .toList()
              ..removeLast(),
          ]),
        ),
        const SizedBox(height: 14),

        // Total
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A1800), Color(0xFF1A0F00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: .5)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.gold.withValues(alpha: .12), blurRadius: 16)
            ],
          ),
          child: Row(children: [
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimated Total',
                      style:
                          TextStyle(color: AppColors.textLight, fontSize: 13)),
                  Text('incl. GST',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ]),
            const Spacer(),
            Text(money(quote!['estimatedPrice']),
                style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 30,
                    fontWeight: FontWeight.w900)),
          ]),
        ),

        // ── Payment Type Selector ──────────────────────────────────────────
        const SizedBox(height: 20),
        const Text(
          'Payment Type',
          style: TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.w700,
              fontSize: 14),
        ),
        const SizedBox(height: 10),
        Builder(builder: (context) {
          final total =
              (quote!['estimatedPrice'] as num?)?.toDouble() ?? 0;
          final advance = total * 0.25;
          return Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _paymentType = 'full'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _paymentType == 'full'
                        ? AppColors.gold.withValues(alpha: .15)
                        : AppColors.navyDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _paymentType == 'full'
                          ? AppColors.gold
                          : AppColors.navyLight,
                      width: _paymentType == 'full' ? 2 : 1,
                    ),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Full Payment',
                          style: TextStyle(
                            color: _paymentType == 'full'
                                ? AppColors.gold
                                : AppColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          money(total),
                          style: TextStyle(
                            color: _paymentType == 'full'
                                ? AppColors.gold
                                : AppColors.textMuted,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pay entire amount',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                      ]),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _paymentType = 'advance'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _paymentType == 'advance'
                        ? AppColors.gold.withValues(alpha: .15)
                        : AppColors.navyDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _paymentType == 'advance'
                          ? AppColors.gold
                          : AppColors.navyLight,
                      width: _paymentType == 'advance' ? 2 : 1,
                    ),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Advance (25%)',
                          style: TextStyle(
                            color: _paymentType == 'advance'
                                ? AppColors.gold
                                : AppColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          money(advance),
                          style: TextStyle(
                            color: _paymentType == 'advance'
                                ? AppColors.gold
                                : AppColors.textMuted,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pay 25% now',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                      ]),
                ),
              ),
            ),
          ]);
        }),

        const SizedBox(height: 20),

        // ── Processing state ───────────────────────────────────────────────
        if (_payProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: AppColors.gold),
              SizedBox(height: 14),
              Text('Processing payment…',
                  style: TextStyle(color: AppColors.textLight)),
            ])),
          ),

        // ── Error / pending banner ─────────────────────────────────────────
        if (_payError != null && !_payProcessing)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_payPending ? AppColors.warning : AppColors.danger)
                  .withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _payPending ? AppColors.warning : AppColors.danger,
              ),
            ),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                _payPending
                    ? Icons.hourglass_top_rounded
                    : Icons.error_outline_rounded,
                color: _payPending ? AppColors.warning : AppColors.danger,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _payError!,
                  style: TextStyle(
                    color: _payPending ? AppColors.warning : AppColors.danger,
                    fontSize: 13,
                  ),
                ),
              ),
            ]),
          ),

        // ── Payment method selector ────────────────────────────────────────
        if (!_payProcessing && !_paySuccess) ...[
          const Text('Select a Payment Method',
              style: TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 12),
          Row(children: [
            _WizardPayMethod(Icons.account_balance_wallet_outlined, 'UPI / GPay',
                AppColors.gold,
                selected: _payMethod == 'upi',
                onTap: () => setState(() { _payMethod = 'upi'; _payError = null; _upiError = null; })),
            const SizedBox(width: 10),
            _WizardPayMethod(Icons.credit_card_outlined, 'Credit / Debit',
                AppColors.info,
                selected: _payMethod == 'card',
                onTap: () => setState(() { _payMethod = 'card'; _payError = null; _upiError = null; })),
            const SizedBox(width: 10),
            _WizardPayMethod(Icons.account_balance_outlined, 'Net Banking',
                AppColors.success,
                selected: _payMethod == 'netbanking',
                onTap: () => setState(() { _payMethod = 'netbanking'; _payError = null; _upiError = null; })),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _WizardPayMethod(Icons.phone_android_outlined, 'Wallets',
                AppColors.warning,
                selected: _payMethod == 'wallet',
                onTap: () => setState(() { _payMethod = 'wallet'; _payError = null; _upiError = null; })),
            const SizedBox(width: 10),
            _WizardPayMethod(Icons.currency_rupee_outlined, 'EMI',
                AppColors.textLight,
                selected: _payMethod == 'emi',
                onTap: () => setState(() { _payMethod = 'emi'; _payError = null; _upiError = null; })),
          ]),
          const SizedBox(height: 16),
          // Dynamic fields based on selected method
          if (_payMethod == 'upi') ..._buildUpiFields(),
          if (_payMethod == 'card') ..._buildCardFields(),
          if (_payMethod == 'netbanking') ..._buildNetBankingFields(),
          if (_payMethod == 'wallet') ..._buildWalletFields(),
          if (_payMethod == 'emi') ..._buildEmiFields(),
          const SizedBox(height: 20),
          // Security badge
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
                  '100% Secure · Powered by Razorpay · PCI DSS Compliant',
                  style:
                      TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          // "Pay & Submit Order" button
          GestureDetector(
            onTap: (_payProcessing || _payLaunched) ? null : _payAndSubmit,
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
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_rounded,
                        color: AppColors.navyDeep, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Pay ${money(_paymentType == 'advance' ? ((quote!["estimatedPrice"] as num?)?.toDouble() ?? 0) * 0.25 : (quote!["estimatedPrice"] as num?)?.toDouble() ?? 0)} & Submit Order',
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
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'You will be redirected to Razorpay secure checkout',
              style:
                  TextStyle(color: AppColors.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        // ── Success + submitting state ─────────────────────────────────────
        if (_paySuccess && _payProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: AppColors.success),
              SizedBox(height: 14),
              Text('Payment confirmed! Submitting your order…',
                  style: TextStyle(color: AppColors.success)),
            ])),
          ),
      ];

  // ── UPI fields ─────────────────────────────────────────────────────────────
  List<Widget> _buildUpiFields() => [
    TextField(
      controller: _upiController,
      keyboardType: TextInputType.text,
      autocorrect: false,
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: AppColors.white),
      decoration: InputDecoration(
        labelText: 'UPI ID (optional)',
        hintText: 'e.g. username@bank',
        prefixIcon: const Icon(Icons.alternate_email, color: AppColors.gold),
        errorText: _upiError,
      ),
      onChanged: (_) {
        if (_upiError != null) setState(() => _upiError = null);
      },
    ),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.navyDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navyLight),
      ),
      child: const Row(children: [
        Icon(Icons.qr_code_2_rounded, color: AppColors.gold, size: 48),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pay via QR Code',
                  style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              SizedBox(height: 4),
              Text('Scan using any UPI app (GPay, PhonePe, Paytm)',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ]),
    ),
  ];

  // ── Card fields ────────────────────────────────────────────────────────────
  List<Widget> _buildCardFields() => [
    TextField(
      controller: _cardNumberCtrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.white),
      maxLength: 19,
      decoration: const InputDecoration(
        labelText: 'Card Number',
        hintText: '1234 5678 9012 3456',
        prefixIcon: Icon(Icons.credit_card_outlined, color: AppColors.info),
        counterText: '',
      ),
      onChanged: (v) {
        // Auto-insert spaces every 4 digits
        final digits = v.replaceAll(' ', '');
        if (digits.length <= 16) {
          final formatted = RegExp(r'.{1,4}')
              .allMatches(digits)
              .map((m) => m.group(0)!)
              .join(' ');
          if (formatted != v) {
            _cardNumberCtrl.value = TextEditingValue(
              text: formatted,
              selection:
                  TextSelection.collapsed(offset: formatted.length),
            );
          }
        }
        if (_payError != null) setState(() => _payError = null);
      },
    ),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(
        child: TextField(
          controller: _expiryCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.white),
          maxLength: 5,
          decoration: const InputDecoration(
            labelText: 'Expiry Date',
            hintText: 'MM/YY',
            prefixIcon: Icon(Icons.calendar_today_outlined,
                color: AppColors.info),
            counterText: '',
          ),
          onChanged: (v) {
            // Auto-add slash but not on backspace (only when length goes 2→3)
            final withoutSlash = v.replaceAll('/', '');
            if (withoutSlash.length == 2 && !v.contains('/')) {
              _expiryCtrl.value = TextEditingValue(
                text: '$withoutSlash/',
                selection: const TextSelection.collapsed(offset: 3),
              );
            }
            if (_payError != null) setState(() => _payError = null);
          },
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: TextField(
          controller: _cvvCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          style: const TextStyle(color: AppColors.white),
          maxLength: 3,
          decoration: const InputDecoration(
            labelText: 'CVV',
            hintText: 'CVV',
            prefixIcon:
                Icon(Icons.lock_outline, color: AppColors.info),
            counterText: '',
          ),
          onChanged: (_) {
            if (_payError != null) setState(() => _payError = null);
          },
        ),
      ),
    ]),
    const SizedBox(height: 12),
    TextField(
      controller: _cardNameCtrl,
      keyboardType: TextInputType.name,
      style: const TextStyle(color: AppColors.white),
      decoration: const InputDecoration(
        labelText: 'Cardholder Name',
        hintText: 'Name on card',
        prefixIcon: Icon(Icons.person_outline, color: AppColors.info),
      ),
      onChanged: (_) {
        if (_payError != null) setState(() => _payError = null);
      },
    ),
  ];

  // ── Net Banking fields ─────────────────────────────────────────────────────
  List<Widget> _buildNetBankingFields() => [
    DropdownButtonFormField<String>(
      initialValue: _selectedBank,
      decoration: const InputDecoration(
        labelText: 'Select Bank',
        prefixIcon: Icon(Icons.account_balance_outlined,
            color: AppColors.success),
      ),
      dropdownColor: AppColors.navyMid,
      style: const TextStyle(color: AppColors.white),
      items: const [
        'SBI',
        'HDFC Bank',
        'ICICI Bank',
        'Axis Bank',
        'Kotak Mahindra',
        'Punjab National Bank',
        'Bank of Baroda',
        'Canara Bank',
        'Yes Bank',
        'IDBI Bank',
      ].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
      onChanged: (v) => setState(() {
        _selectedBank = v;
        if (_payError != null) _payError = null;
      }),
    ),
  ];

  // ── Wallet fields ──────────────────────────────────────────────────────────
  List<Widget> _buildWalletFields() {
    final wallets = [
      const _WalletOption('GPay', Icons.account_balance_wallet_rounded, AppColors.info),
      const _WalletOption('PhonePe', Icons.phone_android_rounded, Color(0xFF5F259F)),
      const _WalletOption('Paytm', Icons.payment_rounded, AppColors.info),
    ];
    return [
      // Use fixed-height containers instead of Expanded inside ListView
      SizedBox(
        height: 90,
        child: Row(
          children: wallets.asMap().entries.map((entry) {
            final idx = entry.key;
            final w   = entry.value;
            final selected = _selectedWallet == w.name;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedWallet = w.name;
                  if (_payError != null) _payError = null;
                }),
                child: Container(
                  margin: EdgeInsets.only(right: idx < wallets.length - 1 ? 10 : 0),
                  decoration: BoxDecoration(
                    color: selected
                        ? w.color.withValues(alpha: .15)
                        : AppColors.navyDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.gold : AppColors.navyLight,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(w.icon,
                          color: selected ? w.color : AppColors.textMuted,
                          size: 28),
                      const SizedBox(height: 6),
                      Text(
                        w.name,
                        style: TextStyle(
                          color: selected ? AppColors.white : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ];
  }
  // ── EMI fields ─────────────────────────────────────────────────────────────
  List<Widget> _buildEmiFields() {
    final total =
        (quote!['estimatedPrice'] as num?)?.toDouble() ?? 0;
    final plans = [3, 6, 9, 12];
    return [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: plans.map((months) {
          final monthly = total / months;
          final selected = _emiMonths == months;
          return GestureDetector(
            onTap: () => setState(() {
              _emiMonths = months;
              if (_payError != null) _payError = null;
            }),
            child: Container(
              width: (MediaQuery.of(context).size.width - 36 - 10) / 2,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold.withValues(alpha: .15)
                    : AppColors.navyDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.navyLight,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$months months',
                      style: TextStyle(
                        color: selected ? AppColors.gold : AppColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${money(monthly)}/month',
                      style: TextStyle(
                        color: selected
                            ? AppColors.gold
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${money(total)} total',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ]),
            ),
          );
        }).toList(),
      ),
    ];
  }

  // ── Heading widget ────────────────────────────────────────────────────────
  Widget _heading(String text, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white)),
          ),
        ]),
      );
}

// ── Payment method card widget (Step 4 only) ──────────────────────────────
class _WizardPayMethod extends StatelessWidget {
  const _WizardPayMethod(this.icon, this.label, this.color,
      {this.selected = false, this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.navyMid : AppColors.navyDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.navyLight,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 5),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (selected)
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
            ]),
          ),
        ),
      );
}

class _WalletOption {
  const _WalletOption(this.name, this.icon, this.color);
  final String name;
  final IconData icon;
  final Color color;
}
