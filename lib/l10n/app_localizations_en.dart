// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get backAgainToLeave => 'Press back again to leave KiBoard';

  @override
  String get forgetPc => 'Forget this PC';

  @override
  String get forgetPcHint =>
      'Pair again from scratch. Use this if the PC changed address or was reinstalled.';

  @override
  String get forgetPcAsk =>
      'This phone will stop being paired with this PC. You can pair again right away.';

  @override
  String get forget => 'Forget';

  @override
  String get identityChanged =>
      'This PC\'s identity changed. Waiting will not fix it.';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Try again';

  @override
  String get windowsFailed => 'Could not reach your PC to list its windows.';

  @override
  String get noOpenWindows => 'No open windows on your PC.';

  @override
  String get isKiboardRunning =>
      'Is KiBoard running on the PC? It sits in the tray, next to the clock.';

  @override
  String get readTheManual => 'How this works';

  @override
  String get appName => 'KiBoard';

  @override
  String get lookingForPcs => 'Looking for PCs on your network…';

  @override
  String get noPcsFound => 'No PCs found on this network yet.';

  @override
  String get noPcsWhy =>
      'Some networks — guest WiFi, plenty of ISP routers — never pass on the messages KiBoard listens for. Typing the address works anyway.';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get enterAddress => 'Enter its address';

  @override
  String get dontSeeYourPc => 'Don\'t see your PC? Enter its address';

  @override
  String get yourPcsAddress => 'Your PC\'s address';

  @override
  String get addressHint =>
      'KiBoard shows it on the PC, under the pairing code. The port is only needed if it is not the usual one.';

  @override
  String get notAnAddress =>
      'That doesn\'t look like an address. It should be like 192.168.1.20 or 192.168.1.20:8770.';

  @override
  String get connect => 'Connect';

  @override
  String get cancel => 'Cancel';

  @override
  String get connecting => 'Connecting…';

  @override
  String get couldNotReach => 'Could not reach that PC.';

  @override
  String wantsToConnect(String host) {
    return '\"$host\" wants to connect';
  }

  @override
  String get enterCode =>
      'Enter the 6-digit code shown on that PC. It expires in 120 s.';

  @override
  String get wrongCode => 'Wrong code — check the PC screen and try again.';

  @override
  String get tooManyAttempts =>
      'Too many wrong attempts. Wait a few minutes and try again.';

  @override
  String get pairingClosed => 'Not accepting new pairings right now';

  @override
  String get connectionDropped =>
      'The connection dropped. Getting a new code — check the PC screen.';

  @override
  String pairFailed(String error) {
    return 'Paired, but the session could not start: $error';
  }

  @override
  String get confirm => 'Confirm';

  @override
  String get offlineRetrying => 'Offline — retrying…';

  @override
  String get revoked => 'This PC revoked access.';

  @override
  String get pairAgain => 'Pair again';

  @override
  String waitingForHost(String host) {
    return 'Waiting for \"$host\".';
  }

  @override
  String get waitingForHostHint =>
      'It will appear here as soon as the PC is awake and on this network.';

  @override
  String get decks => 'Decks';

  @override
  String get auto => 'Auto';

  @override
  String get manual => 'Manual';

  @override
  String get settings => 'Settings';

  @override
  String get openWindows => 'Open windows';

  @override
  String get rightClick => 'Right click';

  @override
  String get listening => 'Listening…';

  @override
  String get holdAndSpeak =>
      'Hold the button and speak.\nThe text is typed on the PC when you let go.';

  @override
  String get micNeeded => 'Microphone permission is needed to dictate.';

  @override
  String get micDenied => 'Microphone denied. Enable it in Android settings.';

  @override
  String get noSpeech => 'Speech recognition is not available on this phone.';

  @override
  String get cannotUndo => 'This one cannot be undone from here.';

  @override
  String keyRefused(String error) {
    return 'That key was refused: $error';
  }

  @override
  String get noAnswer => 'no answer from the PC';

  @override
  String get vibration => 'Vibration';

  @override
  String get sound => 'Sound';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Phone\'s language';

  @override
  String get manualTitle => 'How KiBoard works';

  @override
  String get openManual => 'Manual';

  @override
  String get buyCoffee => 'Buy me a coffee';

  @override
  String get coffeeHint =>
      'KiBoard is free. If it saves you time, this keeps it going.';
}
