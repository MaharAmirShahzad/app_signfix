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
  });
  final String text;
  final String fontFamily;
  final Color  color;
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
        SignBoardTextDesign(text: text, fontFamily: _font, color: _color));
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
                        style: _buildStyle(32, _color).copyWith(
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
