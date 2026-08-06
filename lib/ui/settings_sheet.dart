import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../settings.dart';
import 'manual_screen.dart';
import 'tokens.g.dart';

/// Vibration, sound, language, and the manual. Everything the app has to ask the user, which is
/// almost nothing — a key pad should not need configuring.
///
/// A sheet rather than a screen: three switches do not deserve a page, and the deck stays visible
/// behind them, which is the thing being configured.
Future<void> showSettingsSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(0xFF1E1E20),
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: ValueListenableBuilder<SettingsData>(
      valueListenable: Settings.instance,
      builder: (context, s, _) {
        final t = AppLocalizations.of(context)!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              value: s.haptics,
              onChanged: Settings.instance.setHaptics,
              secondary: const Icon(Icons.vibration, color: Color(DeckTokens.textSecondary)),
              title: Text(t.vibration, style: _title),
            ),
            SwitchListTile(
              value: s.sound,
              onChanged: Settings.instance.setSound,
              secondary: const Icon(Icons.volume_up, color: Color(DeckTokens.textSecondary)),
              title: Text(t.sound, style: _title),
            ),
            ListTile(
              leading: const Icon(Icons.language, color: Color(DeckTokens.textSecondary)),
              title: Text(t.language, style: _title),
              trailing: DropdownButton<String>(
                value: s.languageCode,
                dropdownColor: const Color(0xFF1E1E20),
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: Color(DeckTokens.textPrimary), fontSize: 14),
                items: [
                  // Empty means follow the phone, and it is the default: the user already told
                  // Android what language they read in, and this app is not the place to ask again.
                  DropdownMenuItem(value: '', child: Text(t.languageSystem)),
                  const DropdownMenuItem(value: 'en', child: Text('English')),
                  const DropdownMenuItem(value: 'es', child: Text('Español')),
                ],
                onChanged: (code) => Settings.instance.setLanguage(code ?? ''),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2C2C2E)),
            ListTile(
              leading: const Icon(Icons.menu_book, color: Color(DeckTokens.textSecondary)),
              title: Text(t.openManual, style: _title),
              trailing: const Icon(Icons.chevron_right, color: Color(DeckTokens.textSecondary)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => const ManualScreen()));
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    ),
  ),
);

const _title = TextStyle(color: Color(DeckTokens.textPrimary), fontSize: 15);
