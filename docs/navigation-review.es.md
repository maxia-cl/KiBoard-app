# Revisión de navegación

[English](navigation-review.md) · **Español**

Una revisión de UI de todo el flujo de navegación de la app, hecha el 2026-08-06 sobre
`feat/launcher-feedback`. Los hallazgos van ordenados por **(usuarios afectados × severidad)** y no
por gusto, usando una cohorte supuesta de 100 usuarios. Es un plan para ir despachando, no un
informe para archivar: cada fase es una pieza de trabajo coherente, y el orden importa porque las
primeras desactivan a las siguientes.

## La cohorte supuesta

El ranking depende de esto, y **es supuesto, no medido**. Queda escrito para poder discutirlo.

| Segmento | n | Base |
|---|---|---|
| Primer arranque, nunca emparejado | 100 | todos, una vez |
| Mandan la app a segundo plano y vuelven | 90 | es un teléfono |
| PC dormido o WiFi caída a mitad de sesión | 90 | teléfono en el bolsillo, PC que duerme |
| Usan horizontal al menos a veces | 70 | es un teclado |
| Rotan durante una sesión | 60 | |
| Con una mano al menos a veces | 55 | |
| Mazos de varias páginas | 55 | el mazo Launcher solo ya pagina |
| Interfaz en español | 40 | el producto sale bilingüe |
| Más de un mazo | 30 | |
| Red que bloquea multicast (WiFi de invitados, routers de ISP) | 25 | el propio código lo llama el caso común |
| Cambiarán de PC, reinstalarán el host o tendrán otra IP por DHCP | 25 | a lo largo de un año de uso |
| Fuente del sistema ≥ 1.3× | 20 | población Android |
| Host no instalado o sin arrancar en el primer escaneo | 15 | error de orden de instalación, normal |
| Daltonismo rojo-verde | 6 | ~8% de los hombres |
| TalkBack | 2 | |

## Un hallazgo se verificó y se descartó

La revisión reportó que ir y volver con el interruptor Auto/Manual pierde el mazo elegido, porque
`setMode` omite `deckId` cuando es nulo (`lib/net/ws_layout_source.dart:325`). No es así: el host
sólo toca `s.deck_id` cuando el mensaje trae uno
(`KiBoard-windows-host/src-tauri/src/net/ws.rs:606`), y la sesión recuerda el suyo. Revisar el
teléfono sin leer el host produjo un bug plausible que no existe. **Vale como nota de método: un
hallazgo sobre un viaje de ida y vuelta del protocolo no está confirmado hasta leer los dos
extremos.**

Verificado a mano antes de planificar: cero `PopScope`/`WillPopScope` y cero
`AppLifecycleListener`/`didChangeAppLifecycleState` en `lib/`; el orden de la tira sí se invierte
entre orientaciones; hay 17 cadenas traducidas sin referenciar (no 19).

---

## Fase 1 — la cadena que se retroalimenta

Estos tres se disparan entre sí: el deslizamiento de página hacia atrás lo come el gesto del sistema,
eso se convierte en un back, el back cierra la app, y reabrir cuesta la retención del splash y
aterriza en la espera de 15 segundos. **Arreglar el primero desactiva la cadena**, así que el orden
importa.

### 1.1 El back en el deck cierra la app, o te deja varado en descubrimiento

`crítico` · `95/100` · `lib/ui/boot_screen.dart`, `lib/ui/pair/pairing_code_screen.dart`

No hay ningún `PopScope`, así que el back hace lo que dicte el stack de rutas — y el stack cambia
según cómo llegaste:

- **Relanzamiento, ya emparejado.** `BootScreen` devuelve `DeckScreen` como *widget* dentro de un
  `AnimatedSwitcher`, no como ruta, así que el deck es la raíz. El back no encuentra nada que sacar
  y Android cierra la app.
- **La sesión en la que emparejaste.** `PairingCodeScreen` se empuja sobre `BootScreen`, y el éxito
  hace `pushReplacement`. El stack queda `[BootScreen mostrando DiscoverScreen, DeckScreen]`. El
  back vuelve a una lista de descubrimiento que ya terminaste, sin ruta hacia adelante al deck.
  Matar la app es la única salida.

El back es el único gesto que todo usuario de Android tiene en memoria muscular, y el deck es una
superficie que se toquetea mientras se mira un monitor.

**Arreglo.** `PopScope` en el deck con una política explícita — el primer back avisa, un segundo
dentro de dos segundos sale — y `pushAndRemoveUntil` tras emparejar, para que el deck sea siempre la
raíz y los dos casos converjan.

### 1.2 El deslizamiento de página pelea con el gesto back de Android

`crítico` · `55/100` · `lib/ui/deck/deck_screen.dart`

El `GestureDetector` del arrastre horizontal cubre el bisel de borde a borde. En la navegación por
gestos de Android 10+ el borde izquierdo es del sistema, y Flutter no declara rectángulos de
exclusión — así que "deslizar a la derecha para volver una página" empezando cerca del borde se lo
lleva el sistema y se convierte en 1.1. El modo horizontal está protegido por accidente gracias al
modo inmersivo, a costa de sacar las barras del sistema sobre el deck.

**Arreglo.** Declarar rectángulos de exclusión de gestos para los bordes del deck, o descontar
`MediaQuery.systemGestureInsets` del área de arrastre y aceptar una zona muerta. Hace falta un
dispositivo para confirmar el ancho.

### 1.3 Volver del segundo plano espera hasta 15 s antes de intentarlo

`mayor` · `90/100` · `lib/net/ws_layout_source.dart`

El backoff de reconexión es `500ms × 2^intento` con tope de 15 s, y el contador sólo se reinicia con
una conexión exitosa. Después de que el PC lleve una hora apagado el contador está en su techo, así
que desbloquear el teléfono muestra un deck viejo y "Sin conexión — reintentando…" hasta quince
segundos antes de que la app siquiera intente conectar. Es indistinguible del fallo permanente de
2.1.

Estar sin conexión es un estado normal en esta pantalla y eso es deliberado. **No reintentar no es
lo mismo que estar sin conexión.**

**Arreglo.** Un `AppLifecycleListener` que al volver cancele el reintento pendiente, reinicie el
contador y conecte de inmediato.

---

## Fase 2 — callejones sin salida

### 2.1 No hay forma de olvidar un PC

`crítico` · `25/100` · `lib/ui/settings_sheet.dart` (por ausencia), `lib/net/ws_layout_source.dart`,
`lib/net/pinned_socket.dart`

`SavedSession.clear()` sólo se llama cuando actúa el *host* — un rechazo fatal en `hello`, o el
banner de acceso revocado. El usuario no puede. Tres formas de caer aquí:

- **Cambia la IP.** `WsLayoutSource.ip` es final y la reconexión vuelve a marcar la dirección
  guardada para siempre. No hay redescubrimiento.
- **Se reinstala el host** y su certificado se regenera. `PinnedSocket` lo rechaza, y el fallo es
  deliberadamente no fatal, así que la app reintenta contra un certificado que nunca aceptará.
- **Otro PC.** No hay salida ninguna.

En los tres casos el banner es idéntico al de "el PC está durmiendo", así que nada le dice al
usuario que esto no se va a arreglar solo. La única cura es borrar los datos de la app desde los
ajustes de Android.

**Arreglo.** Una fila "Olvidar este PC" en Ajustes — borra la sesión y hace `pushAndRemoveUntil` a
descubrimiento. Aparte, un certificado que no cuadra debería decirlo en vez de tomar prestado el
texto del PC dormido: ese es el único caso donde emparejar de nuevo es la respuesta.

### 2.2 El cambiador de ventanas puede girar para siempre

`mayor` · `45/100` · `lib/ui/windows/window_switcher_screen.dart`, `lib/ui/deck/deck_screen.dart`

`listWindows` expira lanzando una excepción, y nadie la atrapa, así que `_loading` nunca se limpia:
ocho segundos de espera y luego un spinner eterno. El deck además empuja la pantalla sin esperar la
pulsación y sin mirar el enlace, así que con el host caído entras a una pantalla que no puede
cargar. Un host que reporte cero ventanas deja una cuadrícula vacía y ninguna frase.

El botón de cerrar está fuera de la rama de carga, así que al menos se puede salir.

**Arreglo.** Atrapar el fallo y mostrar el mismo tratamiento de "esperando a tu PC" que el deck ya
usa, con un reintento. Añadir un estado vacío. Y no empujar la pantalla cuando la sesión no está en
línea.

### 2.3 El estado vacío culpa a la red de un host sin arrancar

`mayor` · `15/100` · `lib/ui/pair/discover_screen.dart`

El estado sin PCs explica lo del multicast y ofrece "Buscar de nuevo" y "Escribir la dirección".
Nunca dice *instala y arranca KiBoard en el PC*. Para quien encontró primero la app del teléfono —
el orden natural — todas las salidas que se ofrecen son callejones sin salida. El manual lo explica
perfectamente y está tres niveles más allá, tras un engranaje que esa persona nunca ha abierto.

**Arreglo.** Empezar por la comprobación del host antes que por la explicación de red, y enlazar el
manual desde aquí.

---

## Fase 3 — consistencia y legibilidad

### 3.1 La tira invierte Ajustes y Modo al rotar

`mayor` · `60/100` · `lib/ui/deck/deck_screen.dart`

Vertical es Mazos / Modo / Ajustes; horizontal es Mazos / Ajustes / Modo. Los dos botones son del
mismo tamaño, con icono y palabra, así que buscar el interruptor de modo en horizontal abre una hoja
modal sobre el deck. En un producto cuyo valor declarado es la memoria muscular, el cromo se
reordena solo cuando giras el teléfono.

**Arreglo.** Construir los tres botones una vez en una lista y que cada orientación coloque la misma
lista. Eso además elimina los sitios de llamada duplicados, así que no pueden volver a divergir.

### 3.2 Los puntos de página son el único "dónde estoy", y fallan el contraste dos veces

`mayor` · `55/100`, fallo duro para 6 · `lib/ui/deck/device_bezel.dart`, `lib/ui/tokens.g.dart`

El punto activo es el rojo de marca sobre el extremo oscuro del bisel — alrededor de 1.7:1 — y el
inactivo ronda 2.1:1. Ambos están por debajo del piso de 3:1 para un indicador con significado, y
**activo e inactivo se diferencian en luminancia por algo así como 1.2:1**: lo único que los separa
es el tono, rojo oscuro contra gris oscuro. Además son marcas de 8 px leídas a distancia de brazo
mientras se mira un monitor.

Los puntos, encima, parecen un paginador y no son pulsables.

**Arreglo.** Que la diferencia entre activo e inactivo sea más que tono — claridad, tamaño o un
anillo — y añadir una etiqueta `2/4` al lado; la cuenta ya está a mano. Considerar hacerlos
pulsables, ya que el host es el dueño de la página y esto no es más que otro `set_page`.

### 3.3 Diecisiete cadenas traducidas sin conectar

`mayor` · `40/100` · `lib/l10n/app_en.arb` y sus sitios de llamada

`noPcsWhy`, `addressHint`, `notAnAddress`, `wantsToConnect`, `enterCode`, `pairFailed`,
`waitingForHost`, `waitingForHostHint`, `openWindows`, `rightClick`, `listening`, `holdAndSpeak`,
`micNeeded`, `micDenied`, `noSpeech`, `keyRefused`, `noAnswer` están definidas y traducidas en los
dos idiomas, y no se referencian en ninguna parte. El inglés está incrustado en los sitios de
llamada — incluido el estado vacío de descubrimiento, que es la pantalla más importante para alguien
atascado.

Para un usuario en español detrás de un router que bloquea multicast, la única pantalla que podría
desatascarlo está en un idioma que quizá no lee.

**Arreglo.** Conectarlas; las traducciones ya existen. Y después una comprobación de CI que falle
con claves sin referenciar, o esto vuelve.

### 3.4 Se le muestran códigos de protocolo crudos al usuario

`menor` · `35/100` · `lib/ui/deck/deck_screen.dart`

Una pulsación rechazada mete el código del protocolo directo en un snackbar, así que el usuario lee
`unknown_action`. `keyRefused` ya existe en el `.arb` para exactamente esto. La pantalla de
emparejamiento ya hace lo correcto con sus propios códigos y se puede copiar.

### 3.5 El mensaje `toast` del host se tira a la basura

`menor` · `20/100` · `lib/net/ws_layout_source.dart`

El §4.4 del protocolo define un `toast` de host a teléfono, y la app nunca filtra por él. Es el
único canal del host para contar lo que hizo, lo cual importa precisamente porque el teléfono no
puede saberlo.

---

## Fase 4 — accesibilidad

### 4.1 No hay capa de accesibilidad en absoluto

`mayor para quien lo sufre` · `2/100` · `lib/ui/deck/key_widget.dart`, `lib/ui/deck/key_grid.dart`

Un solo `Semantics` en toda la app, en el logotipo. Consecuencias: una tecla sólo con icono no
anuncia nada; los estados de encendido, actual y arrancando son puramente visuales; el `onDoubleTap`
de cada tecla choca con el gesto de activación de TalkBack; y el deslizamiento de página es un
arrastre crudo sin acción semántica, así que no hay ninguna forma accesible de cambiar de página.
Los tres botones de cerrar no tienen tooltip.

**Arreglo.** Envolver cada tecla en `Semantics` con su etiqueta, su rol de botón y su estado; añadir
tooltips; exponer el cambio de página con `onIncrease`/`onDecrease` en el bisel.

### 4.2 La hoja de Ajustes no tiene scroll

`menor` · `20/100` · `lib/ui/settings_sheet.dart`

Una `Column` pelada. Seis filas con fuente del sistema al 1.3× en horizontal desbordan sin forma de
llegar a las de abajo. Todas las demás superficies largas de la app ya hacen scroll, lo que deja a
esta como la rara. El punto exacto de ruptura necesita un dispositivo; que falte el scroll es un
hecho del código.

---

## Lo que no se resuelve leyendo código

- Si el deslizamiento por el borde izquierdo pierde de verdad contra el gesto del sistema, y qué
  ancho tiene la zona muerta (1.2).
- **La navegación por carpetas.** El teléfono modela `KeyKind.folder` y nunca ramifica por él. Si el
  host reporta una carpeta bajo el mismo `source.id` en la página 0, la clave de página no cambia,
  el switcher no anima y las teclas mutan en el sitio sin movimiento alguno. Hay que abrir una
  carpeta contra el host real y mirar qué llega.
- Si la hoja de Ajustes desborda de verdad, y a qué escala de texto (4.2).
- El orden de recorrido de TalkBack y el choque del doble toque (4.1).
- Qué códigos de error manda el host en la práctica, y si `toast` se usa hoy siquiera.
- Cuánta gente instala primero la app del teléfono. El 15/100 es una suposición; una sesión con
  cinco personas que nunca han visto el producto resolvería el 2.3 y la ubicación del manual mejor
  que cualquier cantidad de lectura.

## Lo que ya está bien — no romperlo

- **El deck se queda arriba con el host dormido y lo dice con una frase**, en vez de girar.
- **La dirección escrita a mano está siempre visible**, no sólo en el estado vacío, y reusa el flujo
  normal de emparejamiento en vez de bifurcarlo.
- **Cada pantalla empujada tiene botón de cerrar y arrastre desde el borde**, y el trackpad suelta un
  arrastre latcheado en `dispose`, así que salirse no puede dejar apretado el botón del ratón del PC.
- **El caché de páginas está indexado por capacidad de grilla, no por forma**, así que rotar no lo
  tira.
- **La confirmación de las teclas peligrosas corre antes de todas las ramas**, así que cubre también
  las teclas del lado del cliente y las pulsaciones largas y dobles.
