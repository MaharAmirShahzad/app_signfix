import 'package:flutter/material.dart';
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
  final length   = TextEditingController(text: '10');
  final width    = TextEditingController(text: '3');
  final quantity = TextEditingController(text: '1');
  final address  = TextEditingController();
  bool installation = true, transportation = true, loading = false;
  Map<String, dynamic>? quote;
  SignBoardTextDesign? _textDesign;

  // 5 steps: 0-TextDesign · 1-Type · 2-Dimensions · 3-Finish · 4-Estimate
  static const _totalSteps = 5;

  static const _types = [
    'LED Sign Board', 'Acrylic Sign Board', 'Flex Sign Board',
    'Glow Sign Board', '3D Letter', 'Channel Letter',
    'Neon Sign', 'Backlit Sign', 'Outdoor Signage', 'Custom Sign Board',
  ];
  static const _materials = ['Acrylic', 'ACP', 'PVC', 'Flex', 'Stainless Steel', 'Aluminium'];
  static const _lightings = ['No Lighting', 'LED', 'Backlit', 'Neon', 'Front Lit', 'Custom'];

  @override
  void dispose() {
    for (final c in [length, width, quantity, address]) {
      c.dispose();
    }
    super.dispose();
  }

  void _err(Object e) => showAppError(context, e);

  Future<void> _calculate() async {
    final l = double.tryParse(length.text);
    final w = double.tryParse(width.text);
    final q = int.tryParse(quantity.text);
    if (l == null || w == null || q == null || l <= 0 || w <= 0 || q <= 0) {
      _err('Enter valid dimensions and quantity.'); return;
    }
    if (address.text.trim().isEmpty) {
      _err('Please enter the delivery / installation address.'); return;
    }
    setState(() => loading = true);
    try {
      quote = await widget.api.calculate({
        'product': type, 'length': l, 'width': w, 'quantity': q,
        'material': material, 'lighting': lighting,
        'installation': installation, 'transportation': transportation,
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
        'product': type,
        'length': double.parse(length.text),
        'width': double.parse(width.text),
        'quantity': int.parse(quantity.text),
        'material': material,
        'lighting': lighting,
        'installation': installation,
        'transportation': transportation,
        'address': address.text.trim(),
        'estimatedPrice': quote!['estimatedPrice'],
        if (_textDesign != null) 'signText': _textDesign!.text,
        if (_textDesign != null) 'signFont': _textDesign!.fontFamily,
        if (_textDesign != null) 'signColor':
            _textDesign!.color.toARGB32().toRadixString(16),
      });
      final id = order['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const ApiException(
          'The server did not return the new order number.',
        );
      }
      if (mounted) {
        await showDialog(context: context, builder: (_) => AlertDialog(
          backgroundColor: AppColors.navyDark,
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
          title: const Text('Order Saved', style: TextStyle(color: AppColors.white)),
          content: Text('$id saved for admin review. Payment will be available after your final quotation is approved.',
              style: const TextStyle(color: AppColors.textLight), textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () { Navigator.pop(context); _reset(); }, child: const Text('OK'))],
        ));
      }
    } catch (e) {
      if (mounted) _err(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _reset() => setState(() { step = 0; quote = null; _textDesign = null; });

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
          _showValidationError('Please enter the delivery / installation address.');
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
                      onPressed: loading
                          ? null
                          : () => setState(() => step = 3),
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
            style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700),
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
          border: Border.all(color: _textDesign!.color.withValues(alpha: .4)),
          boxShadow: [BoxShadow(color: _textDesign!.color.withValues(alpha: .2), blurRadius: 16)],
        ),
        child: Center(
          child: Text(
            _textDesign!.text,
            style: TextStyle(
              fontFamily: _textDesign!.fontFamily,
              fontSize: 28,
              color: _textDesign!.color,
              shadows: [
                Shadow(color: _textDesign!.color.withValues(alpha: .8), blurRadius: 12),
                Shadow(color: _textDesign!.color.withValues(alpha: .4), blurRadius: 24),
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
            final r = await Navigator.push<SignBoardTextDesign>(context,
                MaterialPageRoute(builder: (_) => TextDesignerScreen(initial: _textDesign)));
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
          color: AppColors.navyDark, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.navyLight),
        ),
        child: Column(children: [
          const Icon(Icons.text_fields_rounded, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('Add your sign board text',
              style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          const Text('Choose font, color and preview the neon effect',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final r = await Navigator.push<SignBoardTextDesign>(context,
                  MaterialPageRoute(builder: (_) => const TextDesignerScreen()));
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
      spacing: 8, runSpacing: 8,
      children: _types.map((x) => ChoiceChip(
        label: Text(x),
        selected: type == x,
        selectedColor: AppColors.gold.withValues(alpha: .2),
        checkmarkColor: AppColors.gold,
        onSelected: (_) => setState(() => type = x),
      )).toList(),
    ),
  ];

  // ── Step 2: Dimensions ────────────────────────────────────────────────────
  List<Widget> _step2() => [
    _heading('Dimensions & Delivery', Icons.straighten_rounded),
    Row(children: [
      Expanded(child: TextField(
        controller: length, keyboardType: TextInputType.number,
        style: const TextStyle(color: AppColors.white),
        decoration: const InputDecoration(labelText: 'Length (ft)', prefixIcon: Icon(Icons.height_rounded)),
      )),
      const SizedBox(width: 10),
      Expanded(child: TextField(
        controller: width, keyboardType: TextInputType.number,
        style: const TextStyle(color: AppColors.white),
        decoration: const InputDecoration(labelText: 'Width (ft)', prefixIcon: Icon(Icons.expand_rounded)),
      )),
    ]),
    const SizedBox(height: 12),
    TextField(
      controller: quantity, keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.white),
      decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.format_list_numbered_rounded)),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: address, maxLines: 2,
      style: const TextStyle(color: AppColors.white),
      decoration: const InputDecoration(
        labelText: 'Delivery / installation address',
        prefixIcon: Icon(Icons.location_on_outlined),
      ),
    ),
  ];

  // ── Step 3: Finish & Options ──────────────────────────────────────────────
  List<Widget> _step3() => [
    _heading('Finish & Options', Icons.palette_rounded),
    DropdownButtonFormField<String>(
      initialValue: material,
      decoration: const InputDecoration(labelText: 'Material'),
      dropdownColor: AppColors.navyMid,
      items: _materials.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
      onChanged: (v) => setState(() => material = v!),
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      initialValue: lighting,
      decoration: const InputDecoration(labelText: 'Lighting'),
      dropdownColor: AppColors.navyMid,
      items: _lightings.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
      onChanged: (v) => setState(() => lighting = v!),
    ),
    const SizedBox(height: 12),
    Material(
      color: AppColors.navyDark,
      borderRadius: BorderRadius.circular(14),
      child: Column(children: [
        SwitchListTile(
          value: installation, onChanged: (v) => setState(() => installation = v),
          title: const Text('Installation required'),
          subtitle: const Text('+₹1,500'),
        ),
        const Divider(height: 0, color: AppColors.navyLight),
        SwitchListTile(
          value: transportation, onChanged: (v) => setState(() => transportation = v),
          title: const Text('Transportation required'),
          subtitle: const Text('+₹800'),
        ),
      ]),
    ),
  ];

  // ── Step 4: Quote + Payment ───────────────────────────────────────────────
  List<Widget> _step4() => [
    _heading('Price Estimate', Icons.calculate_rounded),

    // Breakdown
    Container(
      decoration: BoxDecoration(
        color: AppColors.navyDark, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyLight),
      ),
      child: Column(children: [
        ...[
          'productCost', 'materialCost', 'lightingCost',
          'installation', 'transportation', 'gst',
        ].where((k) => (quote![k] ?? 0) > 0).map((k) =>
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Text(humanize(k), style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
              const Spacer(),
              Text(money(quote![k]),
                  style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ).expand((w) => [w, const Divider(height: 0, color: AppColors.navyLight)]).toList()
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
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: .5)),
        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .12), blurRadius: 16)],
      ),
      child: Row(children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Estimated Total', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
          Text('incl. GST', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ]),
        const Spacer(),
        Text(money(quote!['estimatedPrice']),
            style: const TextStyle(color: AppColors.gold, fontSize: 30, fontWeight: FontWeight.w900)),
      ]),
    ),
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.navyDark, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.navyLight),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline, size: 13, color: AppColors.textMuted),
        SizedBox(width: 8),
        Expanded(child: Text('This is an estimate only. Payment becomes available after admin review and your approval of the final quotation.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
      ]),
    ),
    const SizedBox(height: 20),

    SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: loading ? null : _submitOrder,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.navyDeep,
                ),
              )
            : const Icon(Icons.send_rounded),
        label: Text(loading ? 'Submitting order…' : 'Submit order for review'),
      ),
    ),
    const SizedBox(height: 8),
    const Center(child: Text('No payment is collected at this estimate stage.',
        style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
  ];

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
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.white)),
      ),
    ]),
  );
}
