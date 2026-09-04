# Seguridad de datos de Google Play — KiBoard 2.0.2

Respuesta preparada a partir del tráfico real de KiBoard Host 2.0.2 y de las definiciones vigentes
de Google Play. Debe mantenerse sincronizada con `PRIVACY.es.md` y con la política del host.

## Recopilación y seguridad

| Pregunta de Play Console | Respuesta |
| --- | --- |
| ¿La app recopila o comparte alguno de los tipos de datos requeridos? | **Sí** |
| ¿Todos los datos recopilados se cifran en tránsito? | **Sí**. Android se conecta al host mediante WSS con certificado fijado y el host envía analítica mediante HTTPS. |
| ¿Los usuarios pueden solicitar que se borren sus datos? | **No**. Los eventos no contienen cuenta ni identificador permanente y no pueden asociarse a una persona para eliminarlos selectivamente. |
| ¿La app admite creación de cuentas? | **No** |
| ¿La app muestra publicidad? | **No** |

## Tipo que debe marcarse

`Actividad en la app` → `Interacciones con la app`

| Campo | Respuesta |
| --- | --- |
| ¿Se recopila? | **Sí** |
| ¿Se comparte? | **No**. Aptabase actúa como proveedor de servicios que procesa la analítica por cuenta de KiBoard. |
| ¿Se procesa temporalmente? | **No**. Aptabase conserva eventos agregados. |
| ¿Es obligatorio? | **Opcional**. El usuario puede desactivar Analítica en la configuración del host y KiBoard sigue funcionando. |
| Finalidad | **Analítica** |

No marcar ubicación, información personal, información financiera, contactos, archivos, fotos,
audio, historial web, aplicaciones instaladas, registros de fallos ni identificadores del
dispositivo. KiBoard sólo envía identificadores fijos de eventos y contexto funcional general; no
envía nombres de aplicaciones, ventanas, dispositivos, tableros o perfiles, etiquetas o acciones
personalizadas, texto escrito o dictado, audio ni datos de emparejamiento.

## Aclaraciones para revisión

- El `sessionId` de Aptabase es aleatorio y dura únicamente durante la ejecución actual del host;
  no es un identificador del teléfono, del PC ni del usuario.
- El dictado usa el reconocimiento de voz elegido por Android. KiBoard no almacena ni envía audio a
  sus servidores; el texto resultante viaja cifrado sólo al PC emparejado.
- Las pulsaciones viajan al PC por la red local cifrada. Google excluye del formulario los datos
  enviados con cifrado de extremo a extremo cuando sólo emisor y receptor pueden leerlos.
- Si en una versión futura se agregan informes de fallos, cuentas, publicidad, un backend KiBoard o
  nuevos campos de analítica, este formulario deberá actualizarse antes de publicar esa versión.

Fuentes de verificación: ayuda oficial de Google Play sobre Seguridad de datos y política de
privacidad de Aptabase.
