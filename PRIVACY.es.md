# Política de privacidad de KiBoard

Vigente desde: 1 de septiembre de 2026

KiBoard convierte un teléfono o tablet Android en una superficie de control para un PC Windows en
la misma red local. KiBoard no opera servicios de analítica, publicidad, cuentas ni datos en la
nube.

## Datos que maneja la aplicación

- **Conexión de red local:** la app descubre y se conecta al host KiBoard de Windows en la red
  local. El token de emparejamiento, la dirección del host y su certificado se guardan localmente
  en el dispositivo Android para permitir la reconexión.
- **Micrófono:** se accede al micrófono únicamente cuando el usuario inicia el dictado pulsando para
  hablar. El servicio de reconocimiento configurado en Android realiza la transcripción. KiBoard
  envía el texto resultante al host Windows emparejado por la red local; no envía audio a servidores
  operados por KiBoard.
- **Interacciones:** las pulsaciones, movimientos del trackpad y texto ingresado se envían sólo al
  host Windows emparejado para ejecutar la acción solicitada.

KiBoard no vende datos, no muestra publicidad, no crea perfiles de usuario ni comparte datos
personales con el desarrollador. Los datos permanecen en los dispositivos y en la red local del
usuario, salvo cuando el proveedor de reconocimiento de voz de Android procesa un dictado bajo sus
propios términos.

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
