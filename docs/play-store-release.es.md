# Guía de publicación en Google Play

Este repositorio está configurado para generar una versión firmada para Google Play.

## Identidad de la versión

- ID de aplicación: `com.kiboard.kiboard_app`
- Versión: `2.0.2` (`versionCode` 3)
- SDK objetivo y de compilación: Android 16 / API 36
- Artefacto: `build/app/outputs/bundle/release/app-release.aab`
- Licencia: MIT
- Política de privacidad: <https://kiboard-control-deck.honest-pond-9855.chatgpt.site/privacidad>

El ID de aplicación queda permanente después de la primera publicación. Cada versión posterior
debe aumentar el `versionCode` en `pubspec.yaml`.

## Firma

Se debe activar **Play App Signing** y permitir que Google genere y proteja la clave de firma de la
app. KiBoard conserva una clave de subida RSA 4096 separada, usada sólo para autenticar los bundles
enviados a Play Console.

En un PC de desarrollo nuevo, ejecutar una sola vez:

```powershell
.\tool\setup-android-signing.ps1
```

La clave privada queda fuera de Git, bajo `%USERPROFILE%\.kiboard\signing`, junto a un
`android/key.properties` ignorado. Ambos deben respaldarse en un gestor de contraseñas y nunca
subirse al repositorio.

Compilación y verificación local:

```powershell
flutter analyze
flutter test
flutter build appbundle --release
```

El workflow de tags necesita estos secretos de GitHub Actions:

- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_UPLOAD_STORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`

## Play Console

1. Crear KiBoard en Play Console conservando el ID de aplicación actual.
2. Activar Play App Signing con una clave de firma generada por Google.
3. Subir `app-release.aab` primero a Prueba interna.
4. Usar la URL pública de la política de privacidad indicada arriba, después de desplegar el sitio.
5. Completar Seguridad de los datos de forma coherente con la política. KiBoard no usa cuentas,
   publicidad ni un backend propio. Declarar las interacciones de la app recopiladas para
   analítica: el host Windows envía identificadores fijos y contexto general a Aptabase, nunca
   nombres de apps, ventanas, dispositivos o tableros, etiquetas o acciones personalizadas, texto
   ingresado, audio ni datos de emparejamiento. El emparejamiento queda en el dispositivo. El
   dictado invoca el reconocimiento de voz de Android y sólo envía el texto resultante al PC
   emparejado por la red local.
6. Declarar el uso de micrófono para el dictado iniciado por el usuario al mantener pulsado.
7. Completar clasificación de contenido, público objetivo, acceso a la app, publicidad y ficha.
8. Probar la compilación generada por Play en teléfono y tablet antes de promoverla a Producción.

La respuesta preparada campo por campo está en
[`docs/play-data-safety.es.md`](play-data-safety.es.md).

## Texto de la ficha

Descripción breve:

> Convierte tu Android en un tablero de control automático para tu PC Windows.

Descripción completa:

> KiBoard convierte tu teléfono o tablet en un tablero de control por Wi-Fi para Windows. Sigue
> automáticamente la aplicación que estás usando y muestra los controles correctos; el modo Manual
> opcional permite crear tableros propios. Abre o enfoca aplicaciones, ejecuta atajos y macros,
> controla OBS, usa un trackpad inalámbrico y dicta texto. El emparejamiento ocurre directamente en
> la red local mediante una conexión cifrada, sin cuenta KiBoard, publicidad ni nube KiBoard. La
> analítica anónima de interacciones se puede desactivar en Configuración. El host open source para
> Windows es obligatorio y está disponible en el repositorio de KiBoard.

Notas de la versión `2.0.2`:

> KiBoard 2.0.2 mejora la profundidad, contraste y respuesta visual de los botones para que el
> tablero sea más claro al tocarlo. Incluye los tableros automáticos renovados, Launcher de apps
> recientes, íconos en alta resolución y un modo Manual más simple. Requiere KiBoard Host 2.0.2
> para Windows.

## Recursos visuales listos

- Ícono: `store-assets/icon-512.png` — 512×512 PNG.
- Gráfico destacado: `store-assets/feature-graphic-1024x500.png` — 1024×500 PNG sin alfa.
- Teléfono vertical: cuatro capturas 1080×1920 en `store-assets/screenshots/phone-portrait`.
- Teléfono horizontal: cuatro capturas 1920×1080 en `store-assets/screenshots/phone-landscape`.
- Tablet vertical: cuatro capturas 1600×2560 en `store-assets/screenshots/tablet-portrait`.

Textos alternativos sugeridos, en el mismo orden: “Tablero automático de ChatGPT y Codex con
Speed activo”, “Launcher de aplicaciones recientes”, “Tablero Manual personalizado” y
“Configuración de KiBoard con Modo Manual activado”.
