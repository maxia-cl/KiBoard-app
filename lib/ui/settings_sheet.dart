import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../net/saved_session.dart';
import '../settings.dart';
import 'manual_screen.dart';
import 'nav.dart';
import 'pair/discover_screen.dart';
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
        // Scrolls, like every other long surface in this app. Six `ListTile`s at a 1.3x system
        // font in landscape are taller than the ~390 logical pixels the phone has there, and a
        // plain Column simply clips the bottom rows — Manual and the Ko-fi link — with no way to
        // reach them.
        return SingleChildScrollView(
          child: Column(
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
              // Upright only, and it is the one layout choice worth offering: held one-handed,
              // the bottom of a phone is the only part a thumb reaches, so somebody who works that
              // way wants that row to be keys rather than a readout.
              ListTile(
                leading: const Icon(
                  Icons.vertical_align_top,
                  color: Color(DeckTokens.textSecondary),
                ),
                title: Text(t.appPanel, style: _title),
                subtitle: Text(
                  t.appPanelHint,
                  style: const TextStyle(color: Color(DeckTokens.textSecondary), fontSize: 12),
                ),
                trailing: DropdownButton<bool>(
                  value: s.appPanelAtTop,
                  dropdownColor: const Color(0xFF1E1E20),
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(color: Color(DeckTokens.textPrimary), fontSize: 14),
                  items: [
                    DropdownMenuItem(value: false, child: Text(t.panelBottom)),
                    DropdownMenuItem(value: true, child: Text(t.panelTop)),
                  ],
                  onChanged: (top) => Settings.instance.setAppPanelAtTop(top ?? false),
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              ListTile(
                leading: const Icon(Icons.menu_book, color: Color(DeckTokens.textSecondary)),
                title: Text(t.openManual, style: _title),
                trailing: const Icon(Icons.chevron_right, color: Color(DeckTokens.textSecondary)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(screenRoute<void>(const ManualScreen()));
                },
              ),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              // The only way out of a PC the app can no longer reach. Everything else that clears a
              // saved session needs the HOST to act — a revoked token, a rejected hello — so a PC
              // whose IP changed, or that was reinstalled and now serves a certificate the phone
              // will never accept, left the app retrying forever with no exit but clearing its
              // storage from Android settings.
              ListTile(
                leading: const Icon(Icons.link_off, color: Color(DeckTokens.textSecondary)),
                title: Text(t.forgetPc, style: _title),
                subtitle: Text(
                  t.forgetPcHint,
                  style: const TextStyle(color: Color(DeckTokens.textSecondary), fontSize: 12),
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: sheetContext,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E20),
                      title: Text(t.forgetPc, style: _title),
                      content: Text(
                        t.forgetPcAsk,
                        style: const TextStyle(color: Color(DeckTokens.textSecondary)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: Text(
                            t.cancel,
                            style: const TextStyle(color: Color(DeckTokens.textSecondary)),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(DeckTokens.accent),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: Text(t.forget),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await SavedSession.clear();
                  if (!context.mounted) return;
                  // The whole stack goes: what is underneath is a deck for a PC this phone is no
                  // longer paired to, and back must not reach it.
                  Navigator.of(
                    context,
                  ).pushAndRemoveUntil(fadeRoute(DiscoverScreen()), (route) => false);
                },
              ),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              // The same Ko-fi link KiBoard v1 and KiMouse carry. It is a link out, never an
              // in-app purchase: the moment this ships through Play it has to become Billing or
              // leave, which is why it is one ListTile and not a screen.
              ListTile(
                leading: const Icon(Icons.coffee, color: Color(DeckTokens.accent)),
                title: Text(t.buyCoffee, style: _title),
                subtitle: Text(
                  t.coffeeHint,
                  style: const TextStyle(color: Color(DeckTokens.textSecondary), fontSize: 12),
                ),
                onTap: () => launchUrl(
                  Uri.parse('https://ko-fi.com/kiboard'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  ),
);

const _title = TextStyle(color: Color(DeckTokens.textPrimary), fontSize: 15);
