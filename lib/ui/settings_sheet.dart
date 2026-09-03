import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../net/layout_source.dart';
import '../net/saved_session.dart';
import '../settings.dart';
import 'manual_screen.dart';
import 'nav.dart';
import 'pair/discover_screen.dart';
import 'tokens.g.dart';

/// Support, vibration, sound, language, and the manual. Everything the app has to ask the user,
/// which is almost nothing — a key pad should not need configuring.
///
/// A sheet rather than a screen: three switches do not deserve a page, and the deck stays visible
/// behind them, which is the thing being configured.
Future<void> showSettingsSheet(
  BuildContext context, {
  required LayoutSource layoutSource,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(DeckTokens.surface),
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: ValueListenableBuilder<SettingsData>(
      valueListenable: Settings.instance,
      builder: (context, s, _) {
        final t = AppLocalizations.of(context)!;
        // Scrolls, like every other long surface in this app. Six `ListTile`s at a 1.3x system
        // font in landscape are taller than the ~390 logical pixels the phone has there, and a
        // plain Column simply clips the bottom rows — Manual and Forget PC — with no way to reach
        // them.
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Keep support visible instead of burying it below the configuration controls. The
              // same Ko-fi link KiBoard v1 and KiMouse carry; it opens externally and is never an
              // in-app purchase.
              ListTile(
                leading: const Icon(
                  Icons.coffee,
                  color: Color(DeckTokens.accent),
                ),
                title: Text(t.buyCoffee, style: _title),
                subtitle: Text(
                  t.coffeeHint,
                  style: const TextStyle(
                    color: Color(DeckTokens.textSecondary),
                    fontSize: 12,
                  ),
                ),
                onTap: () => launchUrl(
                  Uri.parse('https://ko-fi.com/kiboard'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const Divider(height: 1, color: Color(DeckTokens.surfaceBorder)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.advancedFeatures.toUpperCase(),
                    style: const TextStyle(
                      color: Color(DeckTokens.textSecondary),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              StreamBuilder<bool>(
                stream: layoutSource.manualFeature(),
                initialData: layoutSource.manualEnabled,
                builder: (context, snapshot) => SwitchListTile(
                  value: snapshot.data ?? false,
                  activeThumbColor: const Color(DeckTokens.manualActive),
                  secondary: Icon(
                    Icons.dashboard_customize,
                    color: (snapshot.data ?? false)
                        ? const Color(DeckTokens.manualActive)
                        : const Color(DeckTokens.textSecondary),
                  ),
                  title: Text(t.manualMode, style: _title),
                  subtitle: Text(
                    t.manualModeHint,
                    style: const TextStyle(
                      color: Color(DeckTokens.textSecondary),
                      fontSize: 12,
                    ),
                  ),
                  onChanged: (enabled) async {
                    final showIntro = await layoutSource.setManualEnabled(
                      enabled,
                    );
                    if (!showIntro || !sheetContext.mounted) return;
                    await showDialog<void>(
                      context: sheetContext,
                      builder: (dialogContext) => AlertDialog(
                        backgroundColor: const Color(DeckTokens.surfaceRaised),
                        title: Text(t.manualEnabledTitle, style: _title),
                        content: Text(
                          '${t.manualEnabledBody}\n\n'
                          '1. ${t.manualEnabledStep1}\n'
                          '2. ${t.manualEnabledStep2}\n'
                          '3. ${t.manualEnabledStep3}',
                          style: const TextStyle(
                            color: Color(DeckTokens.textSecondary),
                            height: 1.45,
                          ),
                        ),
                        actions: [
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(
                                DeckTokens.manualActive,
                              ),
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(t.gotIt),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: Color(DeckTokens.surfaceBorder)),
              SwitchListTile(
                value: s.haptics,
                onChanged: Settings.instance.setHaptics,
                secondary: const Icon(
                  Icons.vibration,
                  color: Color(DeckTokens.textSecondary),
                ),
                title: Text(t.vibration, style: _title),
              ),
              SwitchListTile(
                value: s.sound,
                onChanged: Settings.instance.setSound,
                secondary: const Icon(
                  Icons.volume_up,
                  color: Color(DeckTokens.textSecondary),
                ),
                title: Text(t.sound, style: _title),
              ),
              ListTile(
                leading: const Icon(
                  Icons.language,
                  color: Color(DeckTokens.textSecondary),
                ),
                title: Text(t.language, style: _title),
                trailing: SizedBox(
                  width: 112,
                  child: DropdownButton<String>(
                    value: s.languageCode,
                    isExpanded: true,
                    dropdownColor: const Color(DeckTokens.surface),
                    underline: const SizedBox.shrink(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(DeckTokens.textPrimary),
                      fontSize: 14,
                    ),
                    items: [
                      // Empty means follow the phone, and it is the default: the user already told
                      // Android what language they read in, and this app is not the place to ask again.
                      DropdownMenuItem(
                        value: '',
                        child: Text(t.languageSystem),
                      ),
                      const DropdownMenuItem(
                        value: 'en',
                        child: Text('English'),
                      ),
                      const DropdownMenuItem(
                        value: 'es',
                        child: Text('Español'),
                      ),
                    ],
                    onChanged: (code) =>
                        Settings.instance.setLanguage(code ?? ''),
                  ),
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
                  style: const TextStyle(
                    color: Color(DeckTokens.textSecondary),
                    fontSize: 12,
                  ),
                ),
                trailing: SizedBox(
                  width: 112,
                  child: DropdownButton<bool>(
                    value: s.appPanelAtTop,
                    isExpanded: true,
                    dropdownColor: const Color(DeckTokens.surface),
                    underline: const SizedBox.shrink(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(DeckTokens.textPrimary),
                      fontSize: 14,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: false,
                        child: Text(t.panelBottom),
                      ),
                      DropdownMenuItem(value: true, child: Text(t.panelTop)),
                    ],
                    onChanged: (top) =>
                        Settings.instance.setAppPanelAtTop(top ?? false),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(DeckTokens.surfaceBorder)),
              ListTile(
                leading: const Icon(
                  Icons.menu_book,
                  color: Color(DeckTokens.textSecondary),
                ),
                title: Text(t.openManual, style: _title),
                trailing: const Icon(
                  Icons.arrow_right,
                  color: Color(DeckTokens.textSecondary),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(
                    context,
                  ).push(screenRoute<void>(const ManualScreen()));
                },
              ),
              const Divider(height: 1, color: Color(DeckTokens.surfaceBorder)),
              // The only way out of a PC the app can no longer reach. Everything else that clears a
              // saved session needs the HOST to act — a revoked token, a rejected hello — so a PC
              // whose IP changed, or that was reinstalled and now serves a certificate the phone
              // will never accept, left the app retrying forever with no exit but clearing its
              // storage from Android settings.
              ListTile(
                leading: const Icon(
                  Icons.link_off,
                  color: Color(DeckTokens.textSecondary),
                ),
                title: Text(t.forgetPc, style: _title),
                subtitle: Text(
                  t.forgetPcHint,
                  style: const TextStyle(
                    color: Color(DeckTokens.textSecondary),
                    fontSize: 12,
                  ),
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: sheetContext,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: const Color(DeckTokens.surface),
                      title: Text(t.forgetPc, style: _title),
                      content: Text(
                        t.forgetPcAsk,
                        style: const TextStyle(
                          color: Color(DeckTokens.textSecondary),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: Text(
                            t.cancel,
                            style: const TextStyle(
                              color: Color(DeckTokens.textSecondary),
                            ),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(
                              DeckTokens.keyDangerBackground,
                            ),
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
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
                  Navigator.of(context).pushAndRemoveUntil(
                    fadeRoute(DiscoverScreen()),
                    (route) => false,
                  );
                },
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
