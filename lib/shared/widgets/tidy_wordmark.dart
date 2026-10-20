import 'package:flutter/material.dart';

/// Wordmark « tidypics » : « tidy » couleur texte, « pics » couleur principale.
class TidyWordmark extends StatelessWidget {
  const TidyWordmark({super.key, this.fontSize = 48});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -fontSize * 0.03,
      height: 1,
      color: scheme.onSurface,
    );

    return Semantics(
      label: 'TidyPics',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          text: 'tidy',
          style: style,
          children: [
            TextSpan(
              text: 'pics',
              style: TextStyle(color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
