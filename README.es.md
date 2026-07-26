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

**Maqueta de la fase FP construida.** Toda la capa visual —marco, teclas, paginación, carpetas,
pulsación corta/larga/doble, pantallas de descubrimiento y emparejamiento, selector de ventanas—
corre sobre fixtures copiados de `KiBoard-protocol` (ver `lib/mock/README.md`) sin comunicación con
el host, detrás de un `MockLayoutSource` que F3 reemplaza por el cliente WebSocket real.
`flutter analyze` y `flutter test` (incluyendo un test end-to-end del flujo de demo) están limpios.
El siguiente paso es **F0**: fijar `KiBoard-protocol` como submódulo.

## Stack

Flutter (Dart). Targets **Android → iOS**.

## Convenciones

Todo el código va en inglés — identificadores, comentarios, commits y logs. Las cadenas que ve el
usuario viven en archivos `.arb`, nunca en el código. Los documentos van en inglés y español
(`NOMBRE.md` / `NOMBRE.es.md`). Ver
[`CONTRIBUTING.es.md`](https://github.com/maxia-cl/KiBoard-protocol/blob/main/CONTRIBUTING.es.md).
