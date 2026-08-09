/// The manual's prose, `(isHeading, text)`.
///
/// Kept out of `.arb`: these are paragraphs, not interface. A message-per-string file is good at
/// "Cancel" and bad at something that gets rewritten as a whole when the product changes.
library;

const manualEn = <(bool, String)>[
  (
    false,
    'KiBoard turns this phone into a key pad for your PC. The PC does the work; the phone only '
        'says which key was pressed — it never sends the action itself, so a phone that is lost or '
        'stolen cannot be made to do anything the PC would not do anyway.',
  ),
  (true, 'Getting connected'),
  (
    false,
    'Install KiBoard on the PC and leave it running. It sits in the tray.\n\n'
        'The phone finds it by itself on the same Wi-Fi. If the list stays empty it is almost '
        'always the network rather than the app: guest Wi-Fi and a lot of ISP routers block the '
        'discovery messages. Use "Enter its address" and type what the PC shows under the pairing '
        'code — 192.168.1.20, say. The port is only needed when it is not the usual one.\n\n'
        'The PC then shows a six-digit code. Type it on the phone within two minutes. That pairs '
        'THIS phone, with its own key: pairing a second one does not touch the first, and the PC '
        'can revoke either at any time. Three wrong codes and pairing closes for five minutes.',
  ),
  (true, 'Auto mode'),
  (
    false,
    'Auto follows whatever app is in front on the PC. Open Photoshop and the keys become '
        "Photoshop's; move to the browser and they change again, without you touching the phone."
        '\n\nYou arrange nothing for this: the PC ships profiles and picks the one that matches. '
        'When none does, you get a general set that works anywhere.',
  ),
  (true, 'Manual mode and decks'),
  (
    false,
    'Manual shows a deck you arranged yourself in the PC window, and it stays put whatever the PC '
        'is doing. The Decks button lists them and remembers which one you were on.\n\n'
        'The Launcher deck is not arranged by anyone: the PC builds it from the applications '
        'installed on it, with their real icons.',
  ),
  (true, 'What the keys do'),
  (
    false,
    'A short press runs the key. Some keys carry a second action on a long press — those draw a '
        'ring while you hold, so you see it coming and can let go before it fires. Some carry a '
        'third on a double press.\n\n'
        'A key painted red asks before it acts. Those are the ones that close things.\n\n'
        "A key that opens an application stays pressed, with a spinner, until that application's "
        'window actually appears on the PC — and it ignores further presses while it waits, '
        'because it is already working on it.\n\n'
        'A small green dot means the PC says that thing is ON right now: an app that is running, a '
        "microphone that is muted, OBS recording. It is the PC's answer rather than the phone "
        'remembering what you pressed, so changing it on the PC changes the key here too.',
  ),
  (true, 'Pages'),
  (
    false,
    'A deck with more keys than fit spills onto pages. Swipe sideways to move between them; the '
        'dots under the keys say how many there are and where you are.\n\n'
        'Turning the phone does not change which keys you have — the same page is rearranged, not '
        'repaginated, and the keys stay the same size.',
  ),
  (true, 'The trackpad and dictation'),
  (
    false,
    'Two keys open a screen on the phone instead of doing something on the PC. The trackpad is a '
        'mouse: one finger moves, tap to click, two fingers scroll and pinch to zoom. Dictation '
        'types what you say into whatever has focus on the PC — hold the button, speak, let go.',
  ),
  (true, 'When it says it is offline'),
  (
    false,
    'The phone reconnects on its own and the deck works again the moment it does; a banner says so '
        'meanwhile. Sleeping the PC or walking out of range is this, and it needs nothing from '
        'you.\n\n'
        'If it says the PC revoked access, that is the one case where the phone forgets: pair '
        'again.\n\n'
        'If the PC never appears at all, check that both are on the SAME network — a phone on '
        'mobile data or a guest network cannot see it — and that KiBoard was allowed through the '
        'Windows firewall the first time it asked.',
  ),
  (true, 'Settings'),
  (
    false,
    "Vibration and sound can be turned off, and they follow the phone's own settings on top of "
        'that. Language follows the phone unless you pick one; the PC window has its own, taken '
        'from Windows.',
  ),
  (true, 'What travels between phone and PC'),
  (
    false,
    "The connection is encrypted, and the phone remembers the PC's certificate the first time it "
        'pairs — if something else answers at that address later, the phone refuses to talk to it. '
        'What crosses is which key you pressed and what the deck should look like. Nothing you '
        'type on the PC, and no window contents, ever reach the phone.',
  ),
];

const manualEs = <(bool, String)>[
  (
    false,
    'KiBoard convierte este teléfono en una botonera para tu PC. El trabajo lo hace el PC; el '
        'teléfono sólo dice qué tecla se pulsó — nunca manda la acción — así que un teléfono '
        'perdido o robado no puede hacer nada que el PC no fuera a hacer igualmente.',
  ),
  (true, 'Conectarse'),
  (
    false,
    'Instala KiBoard en el PC y déjalo abierto. Vive en la bandeja.\n\n'
        'El teléfono lo encuentra solo en el mismo Wi-Fi. Si la lista se queda vacía casi siempre '
        'es la red y no la aplicación: el Wi-Fi de invitados y muchos routers de operador bloquean '
        'los mensajes de descubrimiento. Usa «Escribe su dirección» y teclea lo que el PC muestra '
        'debajo del código — por ejemplo 192.168.1.20. El puerto sólo hace falta si no es el '
        'habitual.\n\n'
        'El PC enseña entonces un código de seis dígitos. Escríbelo en el teléfono antes de dos '
        'minutos. Eso empareja ESTE teléfono, con su propia clave: emparejar un segundo no toca al '
        'primero, y el PC puede revocar cualquiera cuando quiera. Tres códigos mal y el '
        'emparejamiento se cierra cinco minutos.',
  ),
  (true, 'Modo Auto'),
  (
    false,
    'Auto sigue a la aplicación que tengas delante en el PC. Abres Photoshop y las teclas pasan a '
        'ser las de Photoshop; te vas al navegador y cambian otra vez, sin que toques el '
        'teléfono.\n\n'
        'Para esto no armas nada: el PC trae perfiles hechos y elige el que corresponde. Cuando '
        'ninguno encaja, aparece uno general que sirve en cualquier sitio.',
  ),
  (true, 'Modo Manual y decks'),
  (
    false,
    'Manual muestra un deck que armaste tú en la ventana del PC, y se queda ahí haga lo que haga '
        'el PC. El botón Decks los lista y recuerda en cuál estabas.\n\n'
        'El deck Launcher no lo arma nadie: el PC lo construye con las aplicaciones instaladas en '
        'él, con sus iconos de verdad.',
  ),
  (true, 'Qué hacen las teclas'),
  (
    false,
    'Una pulsación corta ejecuta la tecla. Algunas llevan una segunda acción en la pulsación larga '
        '— esas dibujan un anillo mientras mantienes, así la ves venir y puedes soltar antes de '
        'que dispare. Algunas llevan una tercera en la pulsación doble.\n\n'
        'Una tecla pintada de rojo pregunta antes de actuar. Son las que cierran cosas.\n\n'
        'Una tecla que abre una aplicación se queda hundida, girando, hasta que la ventana aparece '
        'de verdad en el PC — y mientras espera ignora más pulsaciones, porque ya está en ello.\n\n'
        'Un puntito verde significa que el PC dice que eso está encendido ahora mismo: una app '
        'abierta, un micrófono silenciado, OBS grabando. Es la respuesta del PC y no lo que el '
        'teléfono recuerda haber pulsado, así que si lo cambias en el PC la tecla cambia aquí '
        'también.',
  ),
  (true, 'Páginas'),
  (
    false,
    'Un deck con más teclas de las que caben se reparte en páginas. Desliza de lado para moverte; '
        'los puntos bajo las teclas dicen cuántas hay y dónde estás.\n\n'
        'Girar el teléfono no cambia qué teclas tienes — la misma página se recoloca, no se '
        'repagina, y las teclas siguen midiendo lo mismo.',
  ),
  (true, 'El trackpad y el dictado'),
  (
    false,
    'Dos teclas abren una pantalla en el teléfono en vez de hacer algo en el PC. El trackpad es un '
        'ratón: un dedo mueve, tocar es clic, dos dedos hacen scroll y pellizcar hace zoom. El '
        'dictado escribe lo que digas en lo que tengas enfocado en el PC — mantén el botón, habla '
        'y suelta.',
  ),
  (true, 'Cuando dice que está sin conexión'),
  (
    false,
    'El teléfono se reconecta solo y el deck vuelve a funcionar en cuanto lo hace; mientras tanto '
        'un aviso lo dice. Suspender el PC o alejarte del Wi-Fi es esto, y no requiere nada de '
        'ti.\n\n'
        'Si dice que el PC revocó el acceso, ese es el único caso en que el teléfono olvida: '
        'empareja otra vez.\n\n'
        'Si el PC no aparece nunca, comprueba que los dos estén en la MISMA red — un teléfono con '
        'datos móviles o en una red de invitados no lo ve — y que dejaras pasar KiBoard por el '
        'firewall de Windows la primera vez que lo preguntó.',
  ),
  (true, 'Ajustes'),
  (
    false,
    'La vibración y el sonido se pueden apagar, y además respetan los ajustes del propio teléfono. '
        'El idioma sigue al del teléfono salvo que elijas uno; la ventana del PC tiene el suyo, '
        'tomado de Windows.',
  ),
  (true, 'Qué viaja entre el teléfono y el PC'),
  (
    false,
    'La conexión va cifrada, y el teléfono se queda con el certificado del PC la primera vez que '
        'empareja — si más adelante responde otra cosa en esa dirección, se niega a hablar con '
        'ella. Lo que cruza es qué tecla pulsaste y qué aspecto debe tener el deck. Nada de lo que '
        'escribes en el PC, ni el contenido de ninguna ventana, llega nunca al teléfono.',
  ),
];
