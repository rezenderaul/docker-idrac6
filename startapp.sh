#!/bin/sh

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Starting"

SECRETS_DIR="${SECRETS_DIR:-/run/secrets}"

if [ -f "${SECRETS_DIR}/idrac_host" ]; then
    echo "Using Docker secret for IDRAC_HOST"
    IDRAC_HOST="$(cat "${SECRETS_DIR}/idrac_host")"
fi

if [ -f "${SECRETS_DIR}/idrac_port" ]; then
    echo "Using Docker secret for IDRAC_PORT"
    IDRAC_PORT="$(cat "${SECRETS_DIR}/idrac_port")"
fi

if [ -f "${SECRETS_DIR}/idrac_user" ]; then
    echo "Using Docker secret for IDRAC_USER"
    IDRAC_USER="$(cat "${SECRETS_DIR}/idrac_user")"
fi

if [ -f "${SECRETS_DIR}/idrac_password" ]; then
    echo "Using Docker secret for IDRAC_PASSWORD"
    IDRAC_PASSWORD="$(cat "${SECRETS_DIR}/idrac_password")"
fi

if [ -f "${SECRETS_DIR}/idrac_vnc_port" ]; then
    echo "Using Docker secret for IDRAC_VNC_PORT"
    IDRAC_VNC_PORT="$(cat "${SECRETS_DIR}/idrac_vnc_port")"
fi

if [ -f "${SECRETS_DIR}/idrac_socks_proxy_host" ]; then
    echo "Using Docker secret for SOCKS_PROXY_HOST"
    SOCKS_PROXY_HOST="$(cat "${SECRETS_DIR}/idrac_socks_proxy_host")"
fi

if [ -f "${SECRETS_DIR}/idrac_socks_proxy_port" ]; then
    echo "Using Docker secret for SOCKS_PROXY_PORT"
    SOCKS_PROXY_PORT="$(cat "${SECRETS_DIR}/idrac_socks_proxy_port")"
fi

if [ -z "${IDRAC_HOST}" ]; then
    echo "${RED}Please set a proper idrac host with IDRAC_HOST${NC}"
    sleep 2
    exit 1
fi

if [ -z "${IDRAC_PORT}" ]; then
    echo "${RED}Please set a proper idrac port with IDRAC_PORT${NC}"
    sleep 2
    exit 1
fi

if [ -z "${IDRAC_USER}" ]; then
    echo "${RED}Please set a proper idrac user with IDRAC_USER${NC}"
    sleep 2
    exit 1
fi

if [ -z "${IDRAC_PASSWORD}" ]; then
    echo "${RED}Please set a proper idrac password with IDRAC_PASSWORD${NC}"
    sleep 2
    exit 1
fi

if [ -z "${IDRAC_VNC_PORT}" ]; then
    echo "${RED}Please set a proper idrac vnc port with IDRAC_VNC_PORT${NC}"
    sleep 2
    exit 1
fi

echo "Environment ok"

# SOCKS5 opcional (desabilitado por default). Quando SOCKS_PROXY_HOST está
# definida, downloads usam curl via proxy e o java recebe -DsocksProxy*.
if [ -n "${SOCKS_PROXY_HOST:-}" ]; then
    SOCKS_PROXY_PORT="${SOCKS_PROXY_PORT:-1080}"
    echo "Using SOCKS proxy ${SOCKS_PROXY_HOST}:${SOCKS_PROXY_PORT}"
    JAVA_SOCKS_OPTS="-DsocksProxyHost=${SOCKS_PROXY_HOST} -DsocksProxyPort=${SOCKS_PROXY_PORT}"
else
    JAVA_SOCKS_OPTS=""
fi

# Baixa um jar do iDRAC (wget no default, curl via SOCKS quando configurado).
fetch_url() {
    _fetch_out="$1"
    _fetch_url="$2"
    if [ -n "${SOCKS_PROXY_HOST:-}" ]; then
        curl -x "socks5://${SOCKS_PROXY_HOST}:${SOCKS_PROXY_PORT}" -o "$_fetch_out" -k "$_fetch_url"
    else
        wget -O "$_fetch_out" "$_fetch_url" --no-check-certificate
    fi
}

APP_DIR="${APP_DIR:-/app}"
cd "$APP_DIR" || exit 1

if [ ! -d "lib" ]; then
    echo "Creating library folder"
    mkdir -p lib
fi

if [ ! -f avctKVM.jar ]; then
    echo "Downloading avctKVM"

    if ! fetch_url avctKVM.jar "https://${IDRAC_HOST}:${IDRAC_PORT}/software/avctKVM.jar"; then
        echo "${RED}Failed to download avctKVM.jar, please check your settings${NC}"
        sleep 2
        exit 2
    fi
fi

if [ ! -f lib/avctKVMIOLinux64.jar ] && [ ! -f lib/avctKVMIOLinux.jar ]; then
    echo "Downloading avctKVMIOLinux64"

    if ! fetch_url lib/avctKVMIOLinux64.jar "https://${IDRAC_HOST}:${IDRAC_PORT}/software/avctKVMIOLinux64.jar"; then
        echo "Trying fallback avctKVMIOLinux.jar (R710)"
        rm -f lib/avctKVMIOLinux64.jar
        if ! fetch_url lib/avctKVMIOLinux.jar "https://${IDRAC_HOST}:${IDRAC_PORT}/software/avctKVMIOLinux.jar"; then
            echo "${RED}Failed to download avctKVMIOLinux64.jar, please check your settings${NC}"
            sleep 2
            exit 2
        fi
    fi
fi

if [ ! -f lib/avctVMLinux64.jar ]; then
    echo "Downloading avctVMLinux64"

    if ! fetch_url lib/avctVMLinux64.jar "https://${IDRAC_HOST}:${IDRAC_PORT}/software/avctVMLinux64.jar"; then
        echo "${RED}Failed to download avctVMLinux64.jar, please check your settings${NC}"
        sleep 2
        exit 2
    fi
fi

cd lib || exit 1

if [ -f avctKVMIOLinux64.jar ]; then
    if [ ! -f lib/avctKVMIOLinux64.so ] && [ ! -f avctKVMIOLinux64.so ]; then
        echo "Extracting avctKVMIOLinux64"
        jar -xf avctKVMIOLinux64.jar
    fi
elif [ -f avctKVMIOLinux.jar ]; then
    if [ ! -f lib/avctKVMIOLinux.so ] && [ ! -f avctKVMIOLinux.so ]; then
        echo "Extracting avctKVMIOLinux"
        jar -xf avctKVMIOLinux.jar
    fi
fi

if [ ! -f lib/avctVMLinux64.so ]; then
    echo "Extracting avctVMLinux64"

    jar -xf avctVMLinux64.jar
fi

cd "$APP_DIR" || exit 1

echo "${GREEN}Initialization complete, starting virtual console${NC}"

if [ -n "$IDRAC_KEYCODE_HACK" ]; then
    echo "Enabling keycode hack"

    export LD_PRELOAD=/keycode-hack.so
fi
# JAVA_SOCKS_OPTS tem 0 ou 2 flags "-D": word-splitting intencional.
# shellcheck disable=SC2086
exec java -cp avctKVM.jar -Djava.library.path="./lib" ${JAVA_SOCKS_OPTS} com.avocent.idrac.kvm.Main "ip=${IDRAC_HOST}" "kmport=${IDRAC_VNC_PORT}" "vport=${IDRAC_VNC_PORT}" "user=${IDRAC_USER}" "passwd=${IDRAC_PASSWORD}" apcp=1 version=2 vmprivilege=true "helpurl=https://${IDRAC_HOST}:443/help/contents.html" &

# If an iso exists at the specified location, mount it
[ -f "/vmedia/${VIRTUAL_ISO:-}" ] && /mountiso.sh
wait
