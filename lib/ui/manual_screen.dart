import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
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
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F10),
        foregroundColor: const Color(DeckTokens.textPrimary),
        title: Text(t.manualTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final block in (spanish ? _es : _en))
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

/// `(isHeading, text)`.
const _en = <(bool, String)>[
  (
    false,
    'KiBoard turns this phone into a key pad for your PC. The PC does the work; the phone only '
        'says which key was pressed.',
  ),
  (true, 'Getting connected'),
  (
    false,
    'Install KiBoard on the PC and leave it running. The phone finds it by itself on the same '
        'network. If the list stays empty — guest WiFi and many ISP routers block the messages it '
        'listens for — use "Enter its address" and type what the PC shows under the pairing code.\n\n'
        'The PC then shows a six-digit code. Type it on the phone. That pairs this phone only, and '
        'the PC can revoke it on its own at any time.',
  ),
  (true, 'Auto and Manual'),
  (
    false,
    'Auto follows whatever app is in front on the PC: open Photoshop and the keys become '
        'Photoshop\'s. Manual shows a deck you arranged yourself, and the Decks button picks which '
        'one. The Launcher deck is built from the apps installed on that PC.',
  ),
  (true, 'The keys'),
  (
    false,
    'A short press runs the key. Some keys have a second action on a long press — those draw a '
        'ring while you hold. Keys painted red ask before they act.\n\n'
        'A key that opens an app stays pressed, with a spinner, until its window appears on the PC.\n\n'
        'Swipe sideways to change page. The dots under the keys say how many there are.',
  ),
  (true, 'When it says it is offline'),
  (
    false,
    'The phone reconnects by itself and the deck keeps working the moment it does. If it says '
        'the PC revoked access, pair again — that is the one case where the phone forgets.',
  ),
];

const _es = <(bool, String)>[
  (
    false,
    'KiBoard convierte este teléfono en una botonera para tu PC. El trabajo lo hace el PC; el '
        'teléfono sólo dice qué tecla se pulsó.',
  ),
  (true, 'Conectarse'),
  (
    false,
    'Instala KiBoard en el PC y déjalo abierto. El teléfono lo encuentra solo en la misma red. '
        'Si la lista se queda vacía — el WiFi de invitados y muchos routers de operador bloquean los '
        'mensajes que escucha — usa «Escribe su dirección» y teclea lo que el PC muestra debajo del '
        'código.\n\n'
        'El PC enseña entonces un código de seis dígitos. Escríbelo en el teléfono. Eso empareja '
        'sólo este teléfono, y el PC puede revocarlo por su cuenta cuando quiera.',
  ),
  (true, 'Auto y Manual'),
  (
    false,
    'Auto sigue a la aplicación que tengas delante en el PC: abres Photoshop y las teclas pasan '
        'a ser las de Photoshop. Manual muestra un deck que armaste tú, y el botón Decks elige cuál. '
        'El deck Launcher se construye con las aplicaciones instaladas en ese PC.',
  ),
  (true, 'Las teclas'),
  (
    false,
    'Una pulsación corta ejecuta la tecla. Algunas tienen una segunda acción en la pulsación '
        'larga — esas dibujan un anillo mientras mantienes. Las teclas pintadas de rojo preguntan '
        'antes de actuar.\n\n'
        'Una tecla que abre una aplicación se queda hundida, girando, hasta que su ventana aparece '
        'en el PC.\n\n'
        'Desliza de lado para cambiar de página. Los puntos bajo las teclas dicen cuántas hay.',
  ),
  (true, 'Cuando dice que está sin conexión'),
  (
    false,
    'El teléfono se reconecta solo y el deck vuelve a funcionar en cuanto lo hace. Si dice que '
        'el PC revocó el acceso, empareja otra vez — es el único caso en el que el teléfono olvida.',
  ),
];
