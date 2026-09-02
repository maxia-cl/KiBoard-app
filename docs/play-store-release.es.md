# Guía de publicación en Google Play

Este repositorio está configurado para generar una versión firmada para Google Play.

## Identidad de la versión

- ID de aplicación: `com.kiboard.kiboard_app`
- Versión: `2.0.0` (`versionCode` 1)
- SDK objetivo y de compilación: Android 16 / API 36
- Artefacto: `build/app/outputs/bundle/release/app-release.aab`
- Licencia: MIT
- Política de privacidad: <https://github.com/maxia-cl/KiBoard-app/blob/main/PRIVACY.es.md>

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
4. Usar la URL pública de la política de privacidad indicada arriba.
5. Completar Seguridad de los datos de forma coherente con la política: KiBoard no usa cuentas,
   publicidad, analítica ni un backend propio. El emparejamiento queda en el dispositivo. El
   dictado invoca el reconocimiento de voz de Android y sólo envía el texto resultante al PC
   emparejado por la red local.
6. Declarar el uso de micrófono para el dictado iniciado por el usuario al mantener pulsado.
7. Completar clasificación de contenido, público objetivo, acceso a la app, publicidad y ficha.
8. Probar la compilación generada por Play en teléfono y tablet antes de promoverla a Producción.

## Texto de la ficha

Descripción breve:

> Convierte tu Android en un tablero de control automático para tu PC Windows.

Descripción completa:

> KiBoard convierte tu teléfono o tablet en un tablero de control por Wi-Fi para Windows. Sigue
> automáticamente la aplicación que estás usando y muestra los controles correctos; el modo Manual
> opcional permite crear tableros propios. Abre o enfoca aplicaciones, ejecuta atajos y macros,
> controla OBS, usa un trackpad inalámbrico y dicta texto. El emparejamiento ocurre directamente en
> la red local mediante una conexión cifrada, sin cuenta KiBoard, publicidad, analítica ni nube. El
> host open source para Windows es obligatorio y está disponible en el repositorio de KiBoard.

Play Console todavía requiere cargar los recursos visuales: ícono, gráfico de funciones, al menos
dos capturas de teléfono y capturas de tablet si se distribuye para tablets.
