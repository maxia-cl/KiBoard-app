import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @backAgainToLeave.
  ///
  /// In en, this message translates to:
  /// **'Press back again to leave KiBoard'**
  String get backAgainToLeave;

  /// No description provided for @forgetPc.
  ///
  /// In en, this message translates to:
  /// **'Forget this PC'**
  String get forgetPc;

  /// No description provided for @forgetPcHint.
  ///
  /// In en, this message translates to:
  /// **'Pair again from scratch. Use this if the PC changed address or was reinstalled.'**
  String get forgetPcHint;

  /// No description provided for @forgetPcAsk.
  ///
  /// In en, this message translates to:
  /// **'This phone will stop being paired with this PC. You can pair again right away.'**
  String get forgetPcAsk;

  /// No description provided for @forget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get forget;

  /// No description provided for @identityChanged.
  ///
  /// In en, this message translates to:
  /// **'This PC\'s identity changed. Waiting will not fix it.'**
  String get identityChanged;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @windowsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach your PC to list its windows.'**
  String get windowsFailed;

  /// No description provided for @noOpenWindows.
  ///
  /// In en, this message translates to:
  /// **'No open windows on your PC.'**
  String get noOpenWindows;

  /// No description provided for @isKiboardRunning.
  ///
  /// In en, this message translates to:
  /// **'Is KiBoard running on the PC? It sits in the tray, next to the clock.'**
  String get isKiboardRunning;

  /// No description provided for @readTheManual.
  ///
  /// In en, this message translates to:
  /// **'How this works'**
  String get readTheManual;

  /// No description provided for @noSuchKey.
  ///
  /// In en, this message translates to:
  /// **'That key is not on the PC anymore.'**
  String get noSuchKey;

  /// No description provided for @unknownAction.
  ///
  /// In en, this message translates to:
  /// **'The PC did not recognise that key\'s action.'**
  String get unknownAction;

  /// No description provided for @blockedAction.
  ///
  /// In en, this message translates to:
  /// **'The PC refused that action.'**
  String get blockedAction;

  /// No description provided for @keyRefusedGeneric.
  ///
  /// In en, this message translates to:
  /// **'The PC refused that key.'**
  String get keyRefusedGeneric;

  /// No description provided for @yourPc.
  ///
  /// In en, this message translates to:
  /// **'your PC'**
  String get yourPc;

  /// No description provided for @dictate.
  ///
  /// In en, this message translates to:
  /// **'Dictate'**
  String get dictate;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'KiBoard'**
  String get appName;

  /// No description provided for @lookingForPcs.
  ///
  /// In en, this message translates to:
  /// **'Looking for PCs on your network…'**
  String get lookingForPcs;

  /// No description provided for @noPcsFound.
  ///
  /// In en, this message translates to:
  /// **'No PCs found on this network yet.'**
  String get noPcsFound;

  /// No description provided for @noPcsWhy.
  ///
  /// In en, this message translates to:
  /// **'Some networks — guest WiFi, plenty of ISP routers — never pass on the messages KiBoard listens for. Typing the address works anyway.'**
  String get noPcsWhy;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// No description provided for @enterAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter its address'**
  String get enterAddress;

  /// No description provided for @dontSeeYourPc.
  ///
  /// In en, this message translates to:
  /// **'Don\'t see your PC? Enter its address'**
  String get dontSeeYourPc;

  /// No description provided for @yourPcsAddress.
  ///
  /// In en, this message translates to:
  /// **'Your PC\'s address'**
  String get yourPcsAddress;

  /// No description provided for @addressHint.
  ///
  /// In en, this message translates to:
  /// **'KiBoard shows it on the PC, under the pairing code. The port is only needed if it is not the usual one.'**
  String get addressHint;

  /// No description provided for @notAnAddress.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like an address. It should be like 192.168.1.20 or 192.168.1.20:8770.'**
  String get notAnAddress;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @couldNotReach.
  ///
  /// In en, this message translates to:
  /// **'Could not reach that PC.'**
  String get couldNotReach;

  /// No description provided for @wantsToConnect.
  ///
  /// In en, this message translates to:
  /// **'\"{host}\" wants to connect'**
  String wantsToConnect(String host);

  /// No description provided for @enterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code shown on that PC. It expires in 120 s.'**
  String get enterCode;

  /// No description provided for @wrongCode.
  ///
  /// In en, this message translates to:
  /// **'Wrong code — check the PC screen and try again.'**
  String get wrongCode;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong attempts. Wait a few minutes and try again.'**
  String get tooManyAttempts;

  /// No description provided for @pairingClosed.
  ///
  /// In en, this message translates to:
  /// **'Not accepting new pairings right now'**
  String get pairingClosed;

  /// No description provided for @connectionDropped.
  ///
  /// In en, this message translates to:
  /// **'The connection dropped. Getting a new code — check the PC screen.'**
  String get connectionDropped;

  /// No description provided for @pairFailed.
  ///
  /// In en, this message translates to:
  /// **'Paired, but the session could not start: {error}'**
  String pairFailed(String error);

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @offlineRetrying.
  ///
  /// In en, this message translates to:
  /// **'Offline — retrying…'**
  String get offlineRetrying;

  /// No description provided for @revoked.
  ///
  /// In en, this message translates to:
  /// **'This PC revoked access.'**
  String get revoked;

  /// No description provided for @pairAgain.
  ///
  /// In en, this message translates to:
  /// **'Pair again'**
  String get pairAgain;

  /// No description provided for @waitingForHost.
  ///
  /// In en, this message translates to:
  /// **'Waiting for \"{host}\".'**
  String waitingForHost(String host);

  /// No description provided for @waitingForHostHint.
  ///
  /// In en, this message translates to:
  /// **'It will appear here as soon as the PC is awake and on this network.'**
  String get waitingForHostHint;

  /// No description provided for @decks.
  ///
  /// In en, this message translates to:
  /// **'Decks'**
  String get decks;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @openWindows.
  ///
  /// In en, this message translates to:
  /// **'Open windows'**
  String get openWindows;

  /// No description provided for @rightClick.
  ///
  /// In en, this message translates to:
  /// **'Right click'**
  String get rightClick;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get listening;

  /// No description provided for @holdAndSpeak.
  ///
  /// In en, this message translates to:
  /// **'Hold the button and speak.\nThe text is typed on the PC when you let go.'**
  String get holdAndSpeak;

  /// No description provided for @micNeeded.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is needed to dictate.'**
  String get micNeeded;

  /// No description provided for @micDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone denied. Enable it in Android settings.'**
  String get micDenied;

  /// No description provided for @noSpeech.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is not available on this phone.'**
  String get noSpeech;

  /// No description provided for @cannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This one cannot be undone from here.'**
  String get cannotUndo;

  /// No description provided for @noAnswer.
  ///
  /// In en, this message translates to:
  /// **'no answer from the PC'**
  String get noAnswer;

  /// No description provided for @vibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Phone\'s language'**
  String get languageSystem;

  /// No description provided for @manualTitle.
  ///
  /// In en, this message translates to:
  /// **'How KiBoard works'**
  String get manualTitle;

  /// No description provided for @openManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get openManual;

  /// No description provided for @buyCoffee.
  ///
  /// In en, this message translates to:
  /// **'Buy me a coffee'**
  String get buyCoffee;

  /// No description provided for @coffeeHint.
  ///
  /// In en, this message translates to:
  /// **'KiBoard is free. If it saves you time, this keeps it going.'**
  String get coffeeHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
