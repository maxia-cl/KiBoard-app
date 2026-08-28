import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'manual_blocks.dart';
import 'tokens.g.dart';

/// The manual, in whatever language the app is showing.
///
/// Kept as two strings here rather than as `.arb` entries: this is prose, not interface — it has
/// paragraphs and it changes as a whole when the product does, which is exactly the thing a
/// message-per-string file is bad at. The rest of the app goes through `.arb` as it should.
class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final spanish = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      backgroundColor: const Color(DeckTokens.appBackground),
      appBar: AppBar(
        backgroundColor: const Color(DeckTokens.appBackground),
        foregroundColor: const Color(DeckTokens.textPrimary),
        title: Text(t.manualTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final block in (spanish ? manualEs : manualEn))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                block.$2,
                style: block.$1
                    ? const TextStyle(
                        color: Color(DeckTokens.textPrimary),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      )
                    : const TextStyle(
                        color: Color(DeckTokens.textSecondary),
                        fontSize: 14,
                        height: 1.5,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
