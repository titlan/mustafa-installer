# mustafa-installer

Nuevo instalador, parecido a `setup.sh`, pero que ejecuta los instaladores de `titlan/mustafa`.

## Archivo

- `setup-mustafa.sh` — instalador principal. Baja 3 instaladores desde `titlan/mustafa/main` (ssh-vpn, websocket, v2ray), luego baja y corre `install/stunnel.sh` y `install/haproxy.sh` de ese mismo repo, libera el 443 parando sslh, y deja solo a HAProxy escuchando en 443 por SNI.

## Quitados

- **No se instalan:** SSTP (`sstp.sh`), WireGuard (`wg.sh`), Shadowsocks-R (`ssr.sh`), Shadowsocks OBFS (`shadowsocksobfs.sh`) e IPsec (`ipsec.sh`).
- **Se desactivan después de instalar:** OpenVPN, Trojan y Webmin, porque vienen dentro de `ssh-vpn.sh` / `ins-vt.sh` y no se pueden evitar solo quitando un archivo. Quedan parados y deshabilitados para ahorrar memoria en un VPS de 512 MB.

## Uso

En un VPS limpio, como root:

```bash
sudo bash setup-mustafa.sh
```

Pide 3 dominios: principal (V2Ray), SNI para V2Ray y SNI para SSH. Los dos SNI deben ser distintos y apuntar a la IP del VPS.

## Limitaciones

- Los 3 instaladores siguen bajando archivos de ayuda (menús, configs) desde `syapik96/aws`. Este setup solo cambia la fuente de los 3 principales, no es un fork 100% autónomo.
- El certificado debe cubrir los dominios SNI (wildcard o SAN). El script intenta re-emitirlo con los 3 dominios.
- No probado en un VPS limpio todavía.
