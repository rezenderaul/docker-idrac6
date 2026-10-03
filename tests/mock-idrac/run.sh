#!/bin/sh
# Sobe o mock iDRAC HTTPS com cert self-signed gerado em runtime.
# Uso: sh tests/mock-idrac/run.sh [--port 8443] [--cert DIR]
#   --help mostra esta ajuda.
set -eu

PORT=8443
CERTDIR=""
SHOW_HELP=0

while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h) SHOW_HELP=1; shift ;;
        --port) PORT="$2"; shift 2 ;;
        --cert-dir) CERTDIR="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 1 ;;
    esac
done

if [ "$SHOW_HELP" -eq 1 ]; then
    echo "Uso: sh tests/mock-idrac/run.sh [--port 8443] [--cert-dir DIR]"
    echo "Sobe o mock iDRAC HTTPS (rotas /software/*.jar) com cert self-signed."
    echo "Rode em background: sh tests/mock-idrac/run.sh --port 8443 &"
    exit 0
fi

if [ -z "$CERTDIR" ]; then
    CERTDIR="$(mktemp -d)"
    trap 'rm -rf "$CERTDIR"' EXIT
else
    mkdir -p "$CERTDIR"
fi

if [ ! -f "$CERTDIR/cert.pem" ]; then
    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "$CERTDIR/key.pem" -out "$CERTDIR/cert.pem" \
        -days 2 -subj "/CN=mock-idrac" 2>/dev/null
fi

SCRIPT_DIR="$(dirname "$0")"
exec python3 "$SCRIPT_DIR/server.py" --port "$PORT" \
    --cert "$CERTDIR/cert.pem" --key "$CERTDIR/key.pem"
