import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Courbe d'une seule série (espace libéré cumulé) : une ligne de 2 px et
/// une aire claire dessous. Une seule série : pas de légende, le titre de la
/// carte la nomme.
class FreedCurve extends StatelessWidget {
  const FreedCurve({
    super.key,
    required this.values,
    required this.semanticLabel,
    required this.line,
    required this.fill,
    this.height = 96,
  });

  final List<int> values;
  final String semanticLabel;
  final Color line;
  final Color fill;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _CurvePainter(values: values, line: line, fill: fill),
        ),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.values, required this.line, required this.fill});

  final List<int> values;
  final Color line;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxValue = math.max(1, values.reduce(math.max));
    final dx = size.width / (values.length - 1);
    // Marge pour le point final et l'épaisseur du trait.
    const pad = 6.0;
    Offset at(int i) => Offset(
      i * dx,
      pad + (size.height - 2 * pad) * (1 - values[i] / maxValue),
    );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawPath(area, Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      )
      ..drawCircle(at(values.length - 1), 4, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_CurvePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.line != line ||
      oldDelegate.fill != fill;
}

/// Barres d'une seule série (espace libéré par période). Un tap sur une
/// barre affiche sa valeur ; la dernière (période en cours) est mise en avant.
class PeriodBars extends StatefulWidget {
  const PeriodBars({
    super.key,
    required this.values,
    required this.labels,
    required this.format,
    this.height = 150,
  });

  final List<int> values;
  final List<String> labels;
  final String Function(int value) format;
  final double height;

  @override
  State<PeriodBars> createState() => _PeriodBarsState();
}

class _PeriodBarsState extends State<PeriodBars> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final scheme = theme.colorScheme;
    final values = widget.values;
    final maxValue = math.max(1, values.fold(0, math.max));
    final selected = _selected ?? values.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Valeur de la barre choisie, en texte (jamais dans la couleur).
        Text(
          '${widget.labels[selected]} · ${widget.format(math.max(0, values[selected]))}',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: widget.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label:
                        '${widget.labels[i]} : ${widget.format(math.max(0, values[i]))}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selected = i),
                      // Zone de toucher sur toute la hauteur, plus grande
                      // que la barre.
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          widthFactor: 0.72,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            height: math.max(
                              4,
                              widget.height * math.max(0, values[i]) / maxValue,
                            ),
                            decoration: BoxDecoration(
                              color: i == selected ? scheme.primary : tidy.mint,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < values.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: Text(
                  widget.labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tidy.inkMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Une part de la barre de stockage.
class StorageSegment {
  const StorageSegment({
    required this.label,
    required this.bytes,
    required this.color,
  });

  final String label;
  final int bytes;
  final Color color;
}

/// Barre de stockage façon réglages du téléphone : des parts séparées par un
/// trait de 2 px, sur le fond de l'espace libre, avec une légende chiffrée.
class StorageBar extends StatelessWidget {
  const StorageBar({
    super.key,
    required this.total,
    required this.segments,
    required this.freeLabel,
    required this.format,
  });

  final int total;
  final List<StorageSegment> segments;
  final String freeLabel;
  final String Function(int bytes) format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final used = segments.fold(0, (s, e) => s + e.bytes);
    final free = math.max(0, total - used);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: ColoredBox(
              color: tidy.line,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, segment) in segments.indexed)
                    if (segment.bytes > 0)
                      Expanded(
                        flex: math.max(
                          1,
                          (segment.bytes * 1000 / total).round(),
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: i < segments.length - 1 || free > 0 ? 2 : 0,
                          ),
                          child: ColoredBox(color: segment.color),
                        ),
                      ),
                  if (free > 0)
                    Expanded(
                      flex: math.max(1, (free * 1000 / total).round()),
                      child: const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final segment in segments)
              _Legend(
                color: segment.color,
                text: '${segment.label} · ${format(segment.bytes)}',
              ),
            _Legend(
              color: tidy.line,
              text: '$freeLabel · ${format(free)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text, this.style});

  final Color color;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: style ?? Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
