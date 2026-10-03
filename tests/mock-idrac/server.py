#!/usr/bin/env python3
"""Mock iDRAC HTTPS para smoke/CI (fatia 2).

Contrato:
- Rotas: GET /software/<jar> onde <jar> em
  {avctKVM.jar, avctKVMIOLinux64.jar, avctKVMIOLinux.jar, avctVMLinux64.jar}.
  Qualquer outro path -> 404.
- Porta default: 8443 (evita root; startapp.sh usa IDRAC_PORT).
- Access log: uma linha por request em stdout (e em --log-file quando dado),
  formato: `<ISO8601> "GET <path>" <status>`.
- Conteúdo: bytes fake `b"fake-jar <name>"` (NÃO é um jar válido; o smoke
  valida até `Initialization complete`, nunca sessão KVM real).
- TLS: cert/key gerados em runtime (ver run.sh); o script usa
  `wget --no-check-certificate`, então self-signed basta.

Uso:
  python3 server.py --port 8443 --cert cert.pem --key key.pem [--log-file mock.log]
"""

import argparse
import datetime
import http.server
import socket
import ssl
import sys

FAKE_JARS = {
    "avctKVM.jar": b"fake-jar avctKVM",
    "avctKVMIOLinux64.jar": b"fake-jar avctKVMIOLinux64",
    "avctKVMIOLinux.jar": b"fake-jar avctKVMIOLinux",
    "avctVMLinux64.jar": b"fake-jar avctVMLinux64",
}


class Handler(http.server.BaseHTTPRequestHandler):
    log_file = None

    def _log(self, status):
        line = '%s "GET %s" %d' % (
            datetime.datetime.now(datetime.timezone.utc).isoformat(),
            self.path,
            status,
        )
        sys.stdout.write(line + "\n")
        sys.stdout.flush()
        if self.log_file:
            with open(self.log_file, "a") as f:
                f.write(line + "\n")

    def do_GET(self):
        prefix = "/software/"
        if self.path.startswith(prefix):
            name = self.path[len(prefix):].split("?", 1)[0]
            body = FAKE_JARS.get(name)
            if body is not None:
                self.send_response(200)
                self.send_header("Content-Type", "application/java-archive")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                self._log(200)
                return
        self.send_response(404)
        self.end_headers()
        self._log(404)

    def log_message(self, *args):
        pass


class DualStackServer(http.server.HTTPServer):
    """Escuta em IPv4 e IPv6 (wget pode resolver localhost como ::1)."""

    address_family = socket.AF_INET6

    def server_bind(self):
        try:
            self.socket.setsockopt(
                socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0,
            )
        except (AttributeError, OSError):
            pass
        super().server_bind()


def make_server(port, handler):
    try:
        return DualStackServer(("::", port), handler)
    except OSError:
        return http.server.HTTPServer(("0.0.0.0", port), handler)


def main():
    p = argparse.ArgumentParser(description="Mock iDRAC HTTPS (fatia 2).")
    p.add_argument("--port", type=int, default=8443)
    p.add_argument("--cert", required=True)
    p.add_argument("--key", required=True)
    p.add_argument("--log-file", default=None)
    args = p.parse_args()
    Handler.log_file = args.log_file
    srv = make_server(args.port, Handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(args.cert, args.key)
    srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
    print("mock-idrac listening on port %d" % args.port, flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
