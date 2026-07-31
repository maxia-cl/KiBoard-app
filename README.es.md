# KiBoard — app móvil

[English](README.md) · **Español**

La botonera. Una app Flutter que convierte un teléfono o tablet en un **Stream Deck por WiFi**,
emparejado con un host KiBoard en la misma red local.

- **Modo auto** — la botonera sigue a la app en primer plano del PC. ~100 perfiles listos.
- **Modo manual** — mazos que arma el usuario: lanzar apps, disparar macros, controlar OBS.

Dibuja un **Stream Deck físico**: marco, teclas LCD cuadradas, peana y logo. Sin scroll: lo que no
cabe vive en otra página.

## Repositorios relacionados

| Repositorio | Qué es | Visibilidad |
|---|---|---|
| [`KiBoard-protocol`](https://github.com/maxia-cl/KiBoard-protocol) | Contrato de mensajes, tokens visuales, fixtures, documentación | Privado |
| [`KiBoard-windows-host`](https://github.com/maxia-cl/KiBoard-windows-host) | Host de Windows | Privado |
| [`KiBoard-windows-host-releases`](https://github.com/maxia-cl/KiBoard-windows-host-releases) | Instaladores del host y feed de actualización | Público |

`KiBoard-protocol` es la **fuente de verdad**. Primero se cambia ahí, después aquí.

## Estado

**FP hasta F6 listas, F7 a medias.** `KiBoard-protocol` está fijado como submódulo de git en
`KiBoard-protocol/`, tag `v0.3.0-f7`; `lib/ui/tokens.g.dart` se regenera desde ahí con
`tool/generate-tokens.ps1` / `.sh` (Flutter no tiene un hook de prebuild como el de npm, así que es
un paso manual después de mover el pin).

- **F1** — `MdnsDiscovery` (el paquete `nsd`) busca `_kiboard._tcp`, y `PairingClient` hace un
  round-trip real de `pair_request`/`pair_challenge`/`pair_confirm` para conseguir su propio token
  por dispositivo.
- **F2/F3** — el deck corre sobre los datos del host por un `WsLayoutSource` en vivo: la sesión
  persiste y la app arranca directo en el deck, la reconexión se espacia detrás de un aviso de
  enlace, y un socket que se queda mudo sin dar error se da por muerto desde ese silencio. Además:
  háptica, wakelock, el locale del propio teléfono en `hello`, y las pantallas de trackpad y
  dictado portadas de v1.
- **F4/F5/F6** — un arrastre horizontal cambia de página (§4.4 `set_page`), el cromo se va a una
  tira lateral en horizontal porque es la altura la que limita el tamaño de tecla de lado, y las
  teclas de dos estados no necesitaron **ningún cambio en la app**: lo que viaja es una tecla
  normal más `state.on`, que el widget pinta como un punto verde desde F3.
- **F7 hasta ahora** — el selector de decks (`hello_ack` trae la lista desde F1 y el teléfono la
  tiraba, así que el modo manual solo podía caer en `decks[0]`); la **dirección escrita a mano**
  para redes que nunca dejan pasar mDNS, que entra por la pantalla de emparejamiento normal de §2 y
  no por un segundo flujo; y el **fijado del certificado** sobre `wss://` (§2.2).

El fijado guarda el DER entero en vez de un hash: estrictamente más fuerte, ~350 bytes en la sesión
guardada, y ninguna biblioteca de criptografía para la única comparación que hace la app. Una sesión
guardada de antes adopta lo que ve una vez y fija desde ahí — confianza en el primer uso, el trato
de SSH. Es un **cambio que rompe compatibilidad**: teléfono y host hay que recompilarlos e
instalarlos juntos. También deja la app atada a `dart:io`, así que no hay build web.

Sigue abierto en F7: el onboarding de primer uso, y la mitad QR del respaldo de dirección manual —
el teléfono no tiene escáner ni dependencia de cámara.

`flutter analyze` limpio, 35 tests pasando.

## Stack

Flutter (Dart). Targets **Android → iOS**.

## Convenciones

Todo el código va en inglés — identificadores, comentarios, commits y logs. Las cadenas que ve el
usuario viven en archivos `.arb`, nunca en el código. Los documentos van en inglés y español
(`NOMBRE.md` / `NOMBRE.es.md`). Ver
[`CONTRIBUTING.es.md`](https://github.com/maxia-cl/KiBoard-protocol/blob/main/CONTRIBUTING.es.md).
