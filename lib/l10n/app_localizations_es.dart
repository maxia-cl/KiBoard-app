// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get backAgainToLeave => 'Pulsa atrás otra vez para salir de KiBoard';

  @override
  String get appName => 'KiBoard';

  @override
  String get lookingForPcs => 'Buscando PCs en tu red…';

  @override
  String get noPcsFound => 'Todavía no hay ningún PC en esta red.';

  @override
  String get noPcsWhy =>
      'Hay redes — WiFi de invitados, muchos routers de operador — que nunca dejan pasar los mensajes que KiBoard escucha. Escribir la dirección funciona igual.';

  @override
  String get scanAgain => 'Buscar otra vez';

  @override
  String get enterAddress => 'Escribe su dirección';

  @override
  String get dontSeeYourPc => '¿No ves tu PC? Escribe su dirección';

  @override
  String get yourPcsAddress => 'La dirección de tu PC';

  @override
  String get addressHint =>
      'KiBoard la muestra en el PC, debajo del código de emparejamiento. El puerto sólo hace falta si no es el habitual.';

  @override
  String get notAnAddress =>
      'Eso no parece una dirección. Debería ser como 192.168.1.20 o 192.168.1.20:8770.';

  @override
  String get connect => 'Conectar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get connecting => 'Conectando…';

  @override
  String get couldNotReach => 'No se pudo alcanzar ese PC.';

  @override
  String wantsToConnect(String host) {
    return '«$host» quiere conectarse';
  }

  @override
  String get enterCode =>
      'Escribe el código de 6 dígitos que aparece en ese PC. Caduca en 120 s.';

  @override
  String get wrongCode =>
      'Código incorrecto — mira la pantalla del PC e inténtalo de nuevo.';

  @override
  String get tooManyAttempts =>
      'Demasiados intentos fallidos. Espera unos minutos y prueba otra vez.';

  @override
  String get pairingClosed => 'Ahora mismo no acepta emparejamientos nuevos';

  @override
  String get connectionDropped =>
      'Se cortó la conexión. Pidiendo un código nuevo — mira la pantalla del PC.';

  @override
  String pairFailed(String error) {
    return 'Emparejado, pero la sesión no pudo empezar: $error';
  }

  @override
  String get confirm => 'Confirmar';

  @override
  String get offlineRetrying => 'Sin conexión — reintentando…';

  @override
  String get revoked => 'Este PC revocó el acceso.';

  @override
  String get pairAgain => 'Emparejar otra vez';

  @override
  String waitingForHost(String host) {
    return 'Esperando a «$host».';
  }

  @override
  String get waitingForHostHint =>
      'Aparecerá aquí en cuanto el PC esté despierto y en esta red.';

  @override
  String get decks => 'Decks';

  @override
  String get auto => 'Auto';

  @override
  String get manual => 'Manual';

  @override
  String get settings => 'Ajustes';

  @override
  String get openWindows => 'Ventanas abiertas';

  @override
  String get rightClick => 'Clic derecho';

  @override
  String get listening => 'Escuchando…';

  @override
  String get holdAndSpeak =>
      'Mantén pulsado el botón y habla.\nEl texto se escribe en el PC al soltar.';

  @override
  String get micNeeded => 'Hace falta permiso de micrófono para dictar.';

  @override
  String get micDenied =>
      'Micrófono denegado. Actívalo en los ajustes de Android.';

  @override
  String get noSpeech =>
      'El reconocimiento de voz no está disponible en este teléfono.';

  @override
  String get cannotUndo => 'Esta no se puede deshacer desde aquí.';

  @override
  String keyRefused(String error) {
    return 'Esa tecla fue rechazada: $error';
  }

  @override
  String get noAnswer => 'el PC no respondió';

  @override
  String get vibration => 'Vibración';

  @override
  String get sound => 'Sonido';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'El idioma del teléfono';

  @override
  String get manualTitle => 'Cómo funciona KiBoard';

  @override
  String get openManual => 'Manual';

  @override
  String get buyCoffee => 'Regálame un café';

  @override
  String get coffeeHint =>
      'KiBoard es gratis. Si te ahorra tiempo, esto lo mantiene en marcha.';
}
