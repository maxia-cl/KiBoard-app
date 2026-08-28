import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'settings.dart';
import 'ui/boot_screen.dart';
import 'ui/tokens.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read before the first frame: an app that opens in English and turns Spanish a moment later
  // looks broken in a way that taking 5 ms longer to appear does not.
  await Settings.instance.load();
  runApp(const KiBoardApp());
}

class KiBoardApp extends StatelessWidget {
  const KiBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SettingsData>(
      valueListenable: Settings.instance,
      builder: (context, settings, _) => MaterialApp(
        title: 'KiBoard',
        debugShowCheckedModeBanner: false,
        // Null means follow the phone, and it is the default: Android already knows what language
        // the user reads in, so asking again is a setting that exists to be ignored.
        locale: settings.languageCode.isEmpty
            ? null
            : Locale(settings.languageCode),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          // Declared, not inherited: Material 3's default page transition has changed twice, and
          // this app's feel is not something a Flutter upgrade gets to decide. Zoom on Android,
          // the platform slide on iOS. `ui/nav.dart` caps how long either may run.
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
          scaffoldBackgroundColor: const Color(DeckTokens.appBackground),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(DeckTokens.accent),
            brightness: Brightness.dark,
          ),
        ),
        home: const BootScreen(),
      ),
    );
  }
}
