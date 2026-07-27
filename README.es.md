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

**F1 lista** (y antes, F0). `KiBoard-protocol` está fijado como submódulo de git en
`KiBoard-protocol/` (tag `v0.1.0-fp`); `lib/ui/tokens.g.dart` se regenera desde ahí con
`tool/generate-tokens.ps1` / `.sh` (Flutter no tiene un hook de prebuild como el de npm, así que es
un paso manual después de mover el pin).

El descubrimiento y el emparejamiento ya son **reales**: `MdnsDiscovery` (el paquete `nsd`) busca
`_kiboard._tcp` en la red local, y `PairingClient` hace un round-trip real de
`pair_request`/`pair_challenge`/`pair_confirm` sobre un WebSocket de verdad para conseguir su
propio token por dispositivo — verificado contra el host compilado de `KiBoard-windows-host`,
tanto a nivel de protocolo como corriendo el cliente Dart real contra él directamente
(`test/manual_pairing_smoke.dart`). La pantalla del deck que se muestra **después** de emparejar
todavía corre sobre fixtures de `MockLayoutSource`, sin comunicación con el host — eso es trabajo
de F2/F3. `flutter analyze` y `flutter test` están limpios (los widget tests inyectan fakes para
`Discovery` y `Pairing`, ya que ni mDNS ni un socket real existen en un sandbox de test).

## Stack

Flutter (Dart). Targets **Android → iOS**.

## Convenciones

Todo el código va en inglés — identificadores, comentarios, commits y logs. Las cadenas que ve el
usuario viven en archivos `.arb`, nunca en el código. Los documentos van en inglés y español
(`NOMBRE.md` / `NOMBRE.es.md`). Ver
[`CONTRIBUTING.es.md`](https://github.com/maxia-cl/KiBoard-protocol/blob/main/CONTRIBUTING.es.md).
