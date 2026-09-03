# Política de privacidad de KiBoard

Vigente desde: 3 de septiembre de 2026

KiBoard convierte un teléfono o tablet Android en una superficie de control para un PC Windows en
la misma red local. KiBoard no muestra publicidad, no crea cuentas y no vende datos. El host de
Windows utiliza Aptabase para analítica anónima de uso, como se explica a continuación.

## Datos que maneja la aplicación

- **Conexión de red local:** la app descubre y se conecta al host KiBoard de Windows en la red
  local. El token de emparejamiento, la dirección del host y su certificado se guardan localmente
  en el dispositivo Android para permitir la reconexión.
- **Micrófono:** se accede al micrófono únicamente cuando el usuario inicia el dictado pulsando para
  hablar. El servicio de reconocimiento configurado en Android realiza la transcripción. KiBoard
  envía el texto resultante al host Windows emparejado por la red local; no envía audio a servidores
  operados por KiBoard.
- **Interacciones:** las pulsaciones y movimientos del trackpad se envían al host Windows
  emparejado para ejecutar la acción solicitada. El host genera eventos de analítica con el tipo de
  interacción y contexto funcional como modo, posición, tipo de pulsación, identificador de una
  superficie incorporada, orientación y resultado. Los perfiles personalizados se agrupan como una
  sola categoría. El texto ingresado o dictado y el contenido de las acciones no se incluyen en
  esos eventos.

## Analítica anónima

Los eventos se envían desde el host Windows a la región de Estados Unidos de Aptabase. Incluyen la
versión, idioma, sistema operativo, tipo de interacción y un identificador aleatorio limitado a la
ejecución actual del host. No incluyen nombres de aplicaciones, ventanas, dispositivos, tableros o
perfiles; etiquetas o acciones personalizadas; texto escrito o dictado; audio; direcciones locales;
códigos o tokens de emparejamiento ni certificados.

Aptabase indica que genera un identificador diario en el servidor a partir de la dirección IP, el
agente de usuario y una sal rotativa, y que conserva eventos hasta por cinco años. Consulte
<https://aptabase.com/legal/privacy> y la política específica del host en
<https://github.com/maxia-cl/KiBoard-windows-host/blob/main/PRIVACY.es.md>.

KiBoard no vende datos, no muestra publicidad ni crea perfiles persistentes de usuario. La
configuración permanece en los dispositivos y la red local. Las excepciones son el procesamiento
del dictado por el proveedor de reconocimiento de Android y los eventos anónimos descritos arriba.

## Conservación y eliminación

La información de emparejamiento permanece en Android hasta que el usuario se desconecta, borra los
datos de la app o desinstala KiBoard. La configuración del host permanece en el PC hasta que el
usuario la elimina o desinstala el host y borra sus datos.

## Seguridad

KiBoard empareja cada dispositivo con un token propio, usa conexiones WebSocket cifradas y fija el
certificado del host emparejado. Se recomienda emparejar sólo con un PC controlado por el usuario y
usar una red local confiable.

## Menores

KiBoard es una herramienta general de productividad y no está dirigida a menores.

## Contacto

Las consultas de privacidad y solicitudes de eliminación pueden abrirse en
<https://github.com/maxia-cl/KiBoard-app/issues>.

## Cambios

Los cambios importantes se publicarán en este repositorio con una nueva fecha de vigencia.
