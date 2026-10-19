import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Sign Board Text Designer — APK style
//  Type text → pick font → pick color → live neon preview
// ─────────────────────────────────────────────────────────────────────────────

class SignBoardTextDesign {
  const SignBoardTextDesign({
    required this.text,
    required this.fontFamily,
    required this.color,
    this.fontSize = 32,
  });
  final String text;
  final String fontFamily;
  final Color  color;
  final double fontSize;
}

class TextDesignerScreen extends StatefulWidget {
  const TextDesignerScreen({super.key, this.initial});
  final SignBoardTextDesign? initial;

  @override
  State<TextDesignerScreen> createState() => _TextDesignerScreenState();
}

class _TextDesignerScreenState extends State<TextDesignerScreen>
    with SingleTickerProviderStateMixin {

  final _ctrl = TextEditingController();
  String _font  = 'Pacifico';
  Color  _color = const Color(0xFFFF4DA6); // neon pink default
  double _fontSize = 32; // font size slider

  // ── Available fonts ───────────────────────────────────────────────────────
  static const _fonts = [
    'Pacifico',
    'Dancing Script',
    'Great Vibes',
    'Satisfy',
    'Caveat',
    'Permanent Marker',
    'Shadows Into Light',
    'Sacramento',
    'Yellowtail',
    'Kaushan Script',
    'Courgette',
    'Lobster',
  ];

  // ── Preset colors ─────────────────────────────────────────────────────────
  static const _presetColors = [
    Color(0xFFFF4DA6), // neon pink
    Color(0xFF00E5FF), // cyan
    Color(0xFF00FF7F), // neon green
    Color(0xFFAA00FF), // purple
    Color(0xFFFF5722), // orange red
    Color(0xFFFFC107), // amber/gold
    Color(0xFFFFEB3B), // yellow
    Color(0xFFFFFFFF), // white
    Color(0xFF00BFFF), // deep sky blue
    Color(0xFFFF1744), // red
    Color(0xFF76FF03), // light green
    Color(0xFFFF6D00), // deep orange
  ];

  // ── Custom colors (more shades) ───────────────────────────────────────────
  static const _customColors = [
    Color(0xFFE91E63), // pink
    Color(0xFF9C27B0), // purple
    Color(0xFF3F51B5), // indigo
    Color(0xFF2196F3), // blue
    Color(0xFF009688), // teal
    Color(0xFF4CAF50), // green
    Color(0xFFFF9800), // orange
    Color(0xFF795548), // brown
    Color(0xFF607D8B), // blue grey
    Color(0xFF000000), // black
    Color(0xFF9E9E9E), // grey
    Color(0xFFF5F5F5), // white smoke
  ];

  bool _showMore = false;

  // ── Glow animation ────────────────────────────────────────────────────────
  late final AnimationController _glowCtrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _ctrl.text = widget.initial!.text;
      _font      = widget.initial!.fontFamily;
      _color     = widget.initial!.color;
      _fontSize  = widget.initial!.fontSize;
    }
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 6, end: 22).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  TextStyle _buildStyle(double size, Color color) {
    try {
      switch (_font) {
        case 'Pacifico':           return GoogleFonts.pacifico(fontSize: size, color: color);
        case 'Dancing Script':     return GoogleFonts.dancingScript(fontSize: size, color: color, fontWeight: FontWeight.w700);
        case 'Great Vibes':        return GoogleFonts.greatVibes(fontSize: size, color: color);
        case 'Satisfy':            return GoogleFonts.satisfy(fontSize: size, color: color);
        case 'Caveat':             return GoogleFonts.caveat(fontSize: size, color: color, fontWeight: FontWeight.w700);
        case 'Permanent Marker':   return GoogleFonts.permanentMarker(fontSize: size, color: color);
        case 'Shadows Into Light': return GoogleFonts.shadowsIntoLight(fontSize: size, color: color);
        case 'Sacramento':         return GoogleFonts.sacramento(fontSize: size, color: color);
        case 'Yellowtail':         return GoogleFonts.yellowtail(fontSize: size, color: color);
        case 'Kaushan Script':     return GoogleFonts.kaushanScript(fontSize: size, color: color);
        case 'Courgette':          return GoogleFonts.courgette(fontSize: size, color: color);
        case 'Lobster':            return GoogleFonts.lobster(fontSize: size, color: color);
        default:                   return TextStyle(fontSize: size, color: color);
      }
    } catch (_) {
      return TextStyle(fontSize: size, color: color);
    }
  }

  void _done() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type your sign board text.')));
      return;
    }
    Navigator.pop(context,
        SignBoardTextDesign(text: text, fontFamily: _font, color: _color, fontSize: _fontSize));
  }

  @override
  Widget build(BuildContext context) {
    final previewText = _ctrl.text.isEmpty ? 'YOUR TEXT HERE' : _ctrl.text;
    final allColors = _showMore
        ? [..._presetColors, ..._customColors]
        : _presetColors;

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Design Your Sign',
            style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [

                const Text('Type your text, pick a font & color.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 16),

                // ── Text input ───────────────────────────────────────────────
                TextField(
                  controller: _ctrl,
                  maxLength: 24,
                  style: const TextStyle(color: AppColors.white, fontSize: 16),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Type your text',
                    counterStyle: const TextStyle(color: AppColors.textMuted),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textMuted),
                            onPressed: () => setState(() => _ctrl.clear()),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Live Neon Preview ────────────────────────────────────────
                AnimatedBuilder(
                  animation: _glow,
                  builder: (_, __) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF050A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _color.withValues(alpha: .3)),
                      boxShadow: [
                        BoxShadow(
                          color: _color.withValues(alpha: .15),
                          blurRadius: _glow.value * 2,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        previewText,
                        style: _buildStyle(_fontSize, _color).copyWith(
                          shadows: [
                            Shadow(color: _color.withValues(alpha: .9), blurRadius: _glow.value),
                            Shadow(color: _color.withValues(alpha: .6), blurRadius: _glow.value * 2),
                            Shadow(color: _color.withValues(alpha: .3), blurRadius: _glow.value * 4),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Font Size Slider ─────────────────────────────────────────
                Row(children: [
                  const Text('Text Size',
                      style: TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _color.withValues(alpha: .4)),
                    ),
                    child: Text(
                      '${_fontSize.round()}px',
                      style: TextStyle(color: _color, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.text_fields, size: 16, color: AppColors.textMuted),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _color,
                        inactiveTrackColor: AppColors.navyLight,
                        thumbColor: _color,
                        overlayColor: _color.withValues(alpha: .2),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _fontSize,
                        min: 14,
                        max: 64,
                        divisions: 25,
                        onChanged: (v) => setState(() => _fontSize = v),
                      ),
                    ),
                  ),
                  const Icon(Icons.text_fields, size: 24, color: AppColors.textMuted),
                ]),

                // ── Pick Font ────────────────────────────────────────────────
                const Text('Pick Your Font',
                    style: TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: _fonts.length,
                  itemBuilder: (_, i) {
                    final f = _fonts[i];
                    final selected = _font == f;
                    return GestureDetector(
                      onTap: () => setState(() => _font = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.navyMid : AppColors.navyDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? _color : AppColors.navyLight,
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: selected ? [
                            BoxShadow(color: _color.withValues(alpha: .2), blurRadius: 8)
                          ] : [],
                        ),
                        child: Center(
                          child: Text(
                            f.length > 13 ? '${f.substring(0, 12)}…' : f,
                            style: _buildStyle(15, selected ? _color : AppColors.textLight),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ── Pick Color ───────────────────────────────────────────────
                const Text('Pick a Color',
                    style: TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ...allColors.map((c) {
                      final selected = _color.toARGB32() == c.toARGB32();
                      return GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: c.withValues(alpha: selected ? .6 : .25),
                                blurRadius: selected ? 14 : 4,
                              ),
                            ],
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }),
                    // More colors toggle
                    GestureDetector(
                      onTap: () => setState(() => _showMore = !_showMore),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.navyMid,
                          border: Border.all(color: AppColors.navyLight),
                        ),
                        child: Icon(
                          _showMore ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: AppColors.textLight, size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _showMore ? 'Tap ↑ to show fewer' : 'Tap + for more colors',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 30),

                // ── Acrylic Backing Size Calculator ─────────────────────
                _AcrylicSizeCard(text: _ctrl.text),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ── Continue button ──────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: GestureDetector(
                onTap: _done,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: .4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('→  Continue',
                        style: TextStyle(
                          color: AppColors.navyDeep,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        )),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Acrylic Backing Size Calculator ──────────────────────────────────────────
// Automatically calculates recommended acrylic board size based on text length.
// Matches Neon Adda style: dark theme, neon glow, real-time update.

class _AcrylicSize {
  const _AcrylicSize({
    required this.label,      // e.g. "2 × 1 ft"
    required this.sqft,       // e.g. 2.0
    required this.width,      // e.g. 2
    required this.height,     // e.g. 1
    this.isCustom = false,    // true for 21+ chars
  });
  final String label;
  final double sqft;
  final int width;
  final int height;
  final bool isCustom;
}

class _AcrylicSizeCard extends StatelessWidget {
  const _AcrylicSizeCard({required this.text});
  final String text;

  // ── Core business logic ───────────────────────────────────────────────────
  // Count alphanumeric characters only (ignore spaces & special chars)
  static int _charCount(String text) =>
      text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').length;

  // Map character count → acrylic size
  static _AcrylicSize? _calcSize(String text) {
    final count = _charCount(text.trim());
    if (count == 0) return null;                              // empty
    if (count <= 5)  return const _AcrylicSize(label: '1 × 1 ft',   sqft: 1,  width: 1, height: 1);
    if (count <= 10) return const _AcrylicSize(label: '2 × 1 ft',   sqft: 2,  width: 2, height: 1);
    if (count <= 15) return const _AcrylicSize(label: '3 × 1 ft',   sqft: 3,  width: 3, height: 1);
    if (count <= 20) return const _AcrylicSize(label: '4 × 1.5 ft', sqft: 6,  width: 4, height: 2);
    return const _AcrylicSize(label: '5 × 2 ft', sqft: 10, width: 5, height: 2, isCustom: true);
  }

  // ── Pricing ───────────────────────────────────────────────────────────────
  // Base rate: ₹1,500 per sq ft (change this to your actual rate)
  static const double _ratePerSqft = 1500;

  static String _priceLabel(_AcrylicSize size) {
    if (size.isCustom) return 'Contact for Quote';
    final price = (size.sqft * _ratePerSqft).round();
    return '₹${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  // ── Board diagram: proportional box ─────────────────────────────────────
  Widget _boardDiagram(_AcrylicSize size, Color glowColor) {
    // Max width 80, height proportional
    final ratio = size.height / size.width;
    final boxW = 72.0;
    final boxH = (boxW * ratio).clamp(18.0, 72.0);
    return Container(
      width: boxW,
      height: boxH,
      decoration: BoxDecoration(
        color: glowColor.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: glowColor.withValues(alpha: .6), width: 1.5),
        boxShadow: [BoxShadow(color: glowColor.withValues(alpha: .25), blurRadius: 8)],
      ),
      child: Center(
        child: Text(
          size.label,
          style: TextStyle(
            color: glowColor,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = _calcSize(text);
    final count = _charCount(text.trim());
    final isEmpty = text.trim().isEmpty;

    // Color per step: gold → goldLight → info → warning → danger
    final Color glowColor = size == null
        ? AppColors.textMuted
        : size.isCustom
            ? AppColors.danger
            : count <= 5
                ? AppColors.gold
                : count <= 10
                    ? AppColors.goldLight
                    : count <= 15
                        ? AppColors.info
                        : AppColors.warning;

    // Progress: which step is active (0-4)
    final int activeStep = size == null
        ? -1
        : size.isCustom
            ? 4
            : count <= 5
                ? 0
                : count <= 10
                    ? 1
                    : count <= 15
                        ? 2
                        : 3;

    final steps = ['1×1', '2×1', '3×1', '4×1.5', '5×2'];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navyDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEmpty ? AppColors.navyLight : glowColor.withValues(alpha: .45),
          width: isEmpty ? 1 : 1.5,
        ),
        boxShadow: isEmpty
            ? []
            : [BoxShadow(color: glowColor.withValues(alpha: .12), blurRadius: 14)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(children: [
            Icon(Icons.straighten_rounded,
                color: isEmpty ? AppColors.textMuted : glowColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'Acrylic Backing Size',
              style: TextStyle(
                color: isEmpty ? AppColors.textMuted : AppColors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            if (!isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: glowColor.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: glowColor.withValues(alpha: .4)),
                ),
                child: Text(
                  '$count char${count == 1 ? '' : 's'}',
                  style: TextStyle(
                      color: glowColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
          ]),
          const SizedBox(height: 12),

          if (isEmpty) ...[
            // ── Empty state ────────────────────────────────────────────────
            const Center(
              child: Text(
                'Enter text above to see recommended size',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ] else ...[
            // ── Progress steps ─────────────────────────────────────────────
            Row(children: List.generate(steps.length, (i) {
              final isActive = i == activeStep;
              final isDone = i < activeStep;
              return Expanded(
                child: Row(children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDone || isActive ? glowColor : AppColors.navyLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < steps.length - 1) const SizedBox(width: 2),
                ]),
              );
            })),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(steps.length, (i) {
                final isActive = i == activeStep;
                return Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w400,
                    color: isActive ? glowColor : AppColors.textMuted,
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),

            // ── Size + Price + Diagram ─────────────────────────────────────
            Row(children: [
              // Board diagram
              _boardDiagram(size!, glowColor),
              const SizedBox(width: 16),
              // Size & price info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended Size',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      size.label,
                      style: TextStyle(
                        color: glowColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: glowColor.withValues(alpha: .6),
                              blurRadius: 10),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.currency_rupee_rounded,
                          color: AppColors.textLight, size: 13),
                      const SizedBox(width: 2),
                      Text(
                        'Est. Price: ',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                      Text(
                        _priceLabel(size),
                        style: TextStyle(
                          color: size.isCustom
                              ? AppColors.warning
                              : AppColors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ]),
                    Text(
                      '${size.sqft.toStringAsFixed(size.sqft == size.sqft.roundToDouble() ? 0 : 1)} sq ft × ₹1,500/sqft',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ]),

            // ── Custom size warning ────────────────────────────────────────
            if (size.isCustom) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: .35)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.warning, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Large custom size — please contact us for an exact quote.',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          height: 1.4),
                    ),
                  ),
                ]),
              ),
            ],

            // ── Character fill bar ─────────────────────────────────────────
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (count / 30).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppColors.navyLight,
                color: glowColor,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$count / 30 characters',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10),
                ),
                if (count >= 25)
                  Text(
                    'Max 30 chars',
                    style: TextStyle(
                        color: AppColors.danger, fontSize: 10),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
