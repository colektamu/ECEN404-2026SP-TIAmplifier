import 'package:flutter/material.dart';

class DynamicGradientSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String label;
  final List<Color> activeColors;
  final double height;
  final IconData? icon;
  final String? valueText;
  final int? divisions;
  final Color? iconColor;
  final Color? cardColor;
  final Color? textColor;
  final Color? borderColor;

  const DynamicGradientSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.label,
    required this.activeColors,
    this.onChangeEnd,
    this.height = 70,
    this.icon,
    this.valueText,
    this.divisions,
    this.iconColor,
    this.cardColor,
    this.textColor,
    this.borderColor,
  });

  double get normalizedValue {
    if (max == min) return 0;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final t = normalizedValue;
    final displayText = valueText ?? value.toStringAsFixed(1);
    final leadingColor = iconColor ?? activeColors.last;
    final fg = textColor ?? Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: cardColor ?? const Color(0xFF15171A),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: leadingColor.withOpacity(0.14),
                  ),
                  child: Icon(icon, color: leadingColor, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                displayText,
                style: TextStyle(
                  color: fg.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double trackHeight = 18;
                const double trackSidePadding = 18;
                final double usableWidth =
                    (constraints.maxWidth - trackSidePadding * 2)
                        .clamp(0.0, double.infinity);
                final double fillWidth = usableWidth * t;

                return Stack(
                  children: [
                    Positioned(
                      left: trackSidePadding,
                      right: trackSidePadding,
                      top: (height - trackHeight) / 2,
                      child: _TrackBackground(
                        height: trackHeight,
                        color: fg.withOpacity(0.10),
                      ),
                    ),
                    Positioned(
                      left: trackSidePadding,
                      top: (height - trackHeight) / 2,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOut,
                        width: fillWidth,
                        height: trackHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: activeColors,
                            stops: [
                              0.0,
                              (0.55 + t * 0.2).clamp(0.0, 1.0),
                              1.0,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 12 + t * 10,
                              color: activeColors.last.withOpacity(0.35),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: trackHeight,
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          overlayColor: activeColors.last.withOpacity(0.12),
                          thumbColor: fg,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 9,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 18,
                          ),
                        ),
                        child: Slider(
                          value: value.clamp(min, max),
                          min: min,
                          max: max,
                          divisions: divisions,
                          onChanged: onChanged,
                          onChangeEnd: onChangeEnd,
                        ),
                      ),
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
}

class _TrackBackground extends StatelessWidget {
  final double height;
  final Color color;

  const _TrackBackground({
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color,
      ),
    );
  }
}