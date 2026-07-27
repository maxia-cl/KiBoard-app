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

**F0 lista.** `KiBoard-protocol` está fijado como submódulo de git en `KiBoard-protocol/` (tag
`v0.1.0-fp`); `lib/ui/tokens.g.dart` se regenera desde ahí con `tool/generate-tokens.ps1` / `.sh`
(Flutter no tiene un hook de prebuild como el de npm, así que es un paso manual después de mover
el pin).

La **maqueta de la fase FP** —toda la capa visual: marco, teclas, paginación, carpetas, pulsación
corta/larga/doble, pantallas de descubrimiento y emparejamiento, selector de ventanas— corre sobre
fixtures leídos directo del submódulo, sin comunicación con el host, detrás de un
`MockLayoutSource` que F3 reemplaza por el cliente WebSocket real. `flutter analyze` y
`flutter test` (incluyendo un test end-to-end del flujo de demo) están limpios.

## Stack

Flutter (Dart). Targets **Android → iOS**.

## Convenciones

Todo el código va en inglés — identificadores, comentarios, commits y logs. Las cadenas que ve el
usuario viven en archivos `.arb`, nunca en el código. Los documentos van en inglés y español
(`NOMBRE.md` / `NOMBRE.es.md`). Ver
[`CONTRIBUTING.es.md`](https://github.com/maxia-cl/KiBoard-protocol/blob/main/CONTRIBUTING.es.md).
