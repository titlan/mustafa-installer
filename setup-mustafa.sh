#!/bin/bash
# setup-mustafa.sh - Nuevo instalador para titlan/mustafa
# Basado en setup.sh de titlan/full ("Script Mod Modified By Prince", 24-1-22),
# pero bajando los instaladores de titlan/mustafa, no de syapik96/aws.
#
# Que hace, en orden:
#   1. Pide el dominio principal (para el certificado de V2Ray) y los dos
#      dominios SNI de HAProxy (V2Ray y SSH, distintos entre si).
#   2. Baja y corre 3 instaladores de titlan/mustafa/main:
#      ssh-vpn, websocket, v2ray
#      Quitados a peticion de David: SSTP (sstp.sh), WireGuard (wg.sh),
#      Shadowsocks-R (ssr.sh), Shadowsocks OBFS (shadowsocksobfs.sh) e
#      IPsec (ipsec.sh) no se bajan ni se corren. OpenVPN, Trojan y Webmin
#      no tienen instalador propio, vienen dentro de ssh-vpn.sh / ins-vt.sh,
#      asi que despues de instalar se paran y se deshabilitan
#      (ver bloque "Servicios quitados").
#   3. Libera el 443: para y deshabilita sslh y el stunnel original de
#      ssh-vpn.sh, que si no, ocupan el 443 y HAProxy no puede enlazarlo.
#   4. Baja y corre install/stunnel.sh y install/haproxy.sh de titlan/mustafa.
#      Solo HAProxy escucha en 443 y reparte por SNI:
#        dominio V2Ray -> V2Ray TLS 127.0.0.1:8443
#        dominio SSH   -> Stunnel4 TLS 127.0.0.1:8444 -> SSH 127.0.0.1:22
#
# Limitaciones honestas, leelas antes de correrlo en un VPS:
#   - Los 3 instaladores, una vez dentro, siguen bajando archivos de ayuda
#     (menus, configs) desde syapik96/aws. Este setup solo cambia la fuente
#     de los 3 instaladores principales, no es un fork 100% autonomo.
#   - El certificado lo emite ins-vt.sh (acme.sh) solo para el dominio
#     principal. Si los dominios SNI son distintos, el certificado debe
#     cubrirlos (wildcard o SAN con ambos), si no el cliente vera error
#     de certificado. Este script intenta re-emitirlo con los 3 dominios
#     como SAN cuando son distintos; si eso falla, sigue con el cert
#     principal y habra que corregirlo a mano.
#   - No se ha probado en un VPS limpio. Correlo solo en un VPS de pruebas
#     primero, como root, con los dominios ya apuntando a su IP y el 80 libre.
#
# Uso en el VPS: sudo bash setup-mustafa.sh

red='\e[1;31m'
green='\e[1;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
NC='\e[0m'

if [ "${EUID}" -ne 0 ]; then
    echo -e "${red}You need to run this script as root user${NC}"
    exit 1
fi

apt-get update -y
apt-get upgrade -y
apt -y install wget curl
apt-get install screen -y
apt-get autoclean && apt-get autoremove -y

clear
cd

if [[ ! -e /etc/v2ray ]]; then
    mkdir -p /etc/v2ray
fi
if [[ ! -e /var/lib/premium-script ]]; then
    mkdir -p /var/lib/premium-script
fi

echo -e ""
echo -e "  ${red}Ensure the Domain is already routed to cloudflare with proxy off${NC}"
echo -e ""
read -rp "    Domain/Host principal (para V2Ray): " -e host
read -rp "    Dominio SNI para V2Ray (ej. vpn.tu-dominio.com): " -e v2ray_domain
read -rp "    Dominio SNI para SSH (ej. ssh.tu-dominio.com): " -e ssh_domain
echo -e "\e[0m"

if [ -z "$host" ] || [ -z "$v2ray_domain" ] || [ -z "$ssh_domain" ]; then
    echo -e "${red}Faltan dominios, saliendo${NC}"
    exit 1
fi
if [ "$v2ray_domain" = "$ssh_domain" ]; then
    echo -e "${red}Los dos dominios SNI deben ser distintos para que HAProxy los distinga.${NC}"
    exit 1
fi

domain="$host"
echo "IP=$domain" >> /var/lib/premium-script/ipvps.conf
echo "$domain" >> /etc/v2ray/domain
echo "$domain" >> /root/domain
echo "$v2ray_domain" > /root/v2ray_domain
echo "$ssh_domain" > /root/ssh_domain
sleep 2
clear
echo -e "        ${green}Dominios guardados, empieza la instalacion${NC}"
sleep 3
clear
cd

# Fuente: titlan/mustafa, no syapik96/aws
MustafaUser="titlan"
MustafaRepo="mustafa"
MustafaBase="https://raw.githubusercontent.com/${MustafaUser}/${MustafaRepo}/main"

wget ${MustafaBase}/install/ssh-vpn.sh && chmod +x ssh-vpn.sh && screen -S ssh-vpn.sh ./ssh-vpn.sh
wget ${MustafaBase}/websocket-python/websocket.sh && chmod +x websocket.sh && screen -S websocket.sh ./websocket.sh
# SSTP, WireGuard, Shadowsocks-R, Shadowsocks OBFS e IPsec quitados:
# no se bajan sstp.sh, wg.sh, ssr.sh, shadowsocksobfs.sh ni ipsec.sh
wget ${MustafaBase}/install/ins-vt.sh && chmod +x ins-vt.sh && sed -i -e 's/\r$//' /root/ins-vt.sh && screen -S v2ray.sh ./ins-vt.sh

# Remove script has installed
rm -f /root/ssh-vpn.sh /root/websocket.sh /root/ins-vt.sh

# --- Servicios quitados a peticion de David ---
# OpenVPN, Trojan y Webmin vienen dentro de ssh-vpn.sh / ins-vt.sh, no se
# pueden evitar solo quitando un archivo, asi que se paran y deshabilitan.
echo -e "${yellow}Desactivando OpenVPN, Trojan y Webmin (no los usas)...${NC}"
systemctl stop openvpn 2>/dev/null || true
systemctl disable openvpn 2>/dev/null || true
systemctl stop openvpn@server 2>/dev/null || true
systemctl disable openvpn@server 2>/dev/null || true
systemctl stop trojan 2>/dev/null || true
systemctl disable trojan 2>/dev/null || true
systemctl stop webmin 2>/dev/null || true
systemctl disable webmin 2>/dev/null || true
/etc/init.d/webmin stop 2>/dev/null || true

history -c
echo "2.1" >> /home/ver

# --- Cableado HAProxy / Stunnel4 (titlan/mustafa) ---
echo -e "${yellow}Liberando el puerto 443 para HAProxy...${NC}"
systemctl stop sslh 2>/dev/null || true
systemctl disable sslh 2>/dev/null || true
systemctl stop stunnel4 2>/dev/null || true

# Si los dominios SNI son distintos al principal, intentar cert con SAN
if [ "$v2ray_domain" != "$domain" ] || [ "$ssh_domain" != "$domain" ]; then
    echo -e "${yellow}Re-emitiendo certificado con los 3 dominios como SAN (puerto 80)...${NC}"
    /root/.acme.sh/acme.sh --issue -d "$domain" -d "$v2ray_domain" -d "$ssh_domain" --standalone -k ec-256 2>/dev/null || true
    /root/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc 2>/dev/null || true
fi

cd /root
wget ${MustafaBase}/install/stunnel.sh && chmod +x stunnel.sh && bash stunnel.sh
wget ${MustafaBase}/install/haproxy.sh && chmod +x haproxy.sh
printf "%s\n%s\n" "$v2ray_domain" "$ssh_domain" | bash haproxy.sh

clear
echo -e "=================-AutoScript VPN-Batch-====================" | tee -a log-install.txt
echo "" | tee -a log-install.txt
echo "   - OpenSSH                  : 22,777" | tee -a log-install.txt
echo "   - HAProxy (443, por SNI)   : solo HAProxy escucha en 443" | tee -a log-install.txt
echo "   - V2RAY Vmess TLS          : 443 via HAProxy -> 8443 interno" | tee -a log-install.txt
echo "   - V2RAY Vmess TLS SNI      : $v2ray_domain" | tee -a log-install.txt
echo "   - Stunnel4 / SSH           : 443 via HAProxy -> 8444 interno -> SSH 22" | tee -a log-install.txt
echo "   - Stunnel4 / SSH SNI       : $ssh_domain" | tee -a log-install.txt
echo "   - V2RAY Vless TLS          : 2083" | tee -a log-install.txt
echo "   - Quitados / desactivados  : OpenVPN, Trojan, WireGuard, SSTP, Webmin, Shadowsocks-R, Shadowsocks OBFS, IPsec" | tee -a log-install.txt
echo "" | tee -a log-install.txt
echo "   - Fuente de instaladores   : titlan/mustafa" | tee -a log-install.txt
echo "   - Installation Log --> /root/log-install.txt" | tee -a log-install.txt
echo "" | tee -a log-install.txt
echo "Verifica en el VPS: ss -tlnp | grep 443  (solo debe salir haproxy)"
echo "y: haproxy -c -f /etc/haproxy/haproxy.cfg"
sleep 8
clear
echo "Instalacion terminada. Revisa el resumen de arriba antes de reiniciar."
echo "Si todo esta bien, corre: reboot"
