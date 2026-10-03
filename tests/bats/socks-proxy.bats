#!/usr/bin/env bats
# Contrato socks-proxy: sem proxy usa wget e sem flags java;
# com proxy usa curl -x socks5:// e flags -DsocksProxy* como argv únicos.

setup() {
  export BATS_TMPDIR_TMP="$(mktemp -d)"
  export APP_DIR="$BATS_TMPDIR_TMP/app"
  mkdir -p "$APP_DIR/lib"
  export SECRETS_DIR="$BATS_TMPDIR_TMP/secrets"
  mkdir -p "$SECRETS_DIR"
  export PATH="$BATS_TEST_DIRNAME/bin:$PATH"
  export FAKE_WGET_LOG="$BATS_TMPDIR_TMP/wget.log"
  export FAKE_CURL_LOG="$BATS_TMPDIR_TMP/curl.log"
  export FAKE_JAVA_LOG="$BATS_TMPDIR_TMP/java.log"
  export FAKE_JAR_LOG="$BATS_TMPDIR_TMP/jar.log"
  export IDRAC_HOST="idrac.test"
  export IDRAC_PORT="443"
  export IDRAC_USER="root"
  export IDRAC_PASSWORD="secret"
  export IDRAC_VNC_PORT="5900"
  : > "$FAKE_WGET_LOG"; : > "$FAKE_CURL_LOG"
  : > "$FAKE_JAVA_LOG"; : > "$FAKE_JAR_LOG"
  export VIRTUAL_ISO=""
  unset SOCKS_PROXY_HOST SOCKS_PROXY_PORT
  touch "$APP_DIR/avctKVM.jar" "$APP_DIR/lib/avctKVMIOLinux64.jar" "$APP_DIR/lib/avctVMLinux64.jar"
}

teardown() {
  jobs -p | xargs -r kill 2>/dev/null || true
  rm -rf "$BATS_TMPDIR_TMP"
}

@test "default: sem proxy usa wget e sem flags socks no java" {
  run timeout 5 bash "$BATS_TEST_DIRNAME/../../startapp.sh"
  [ "$status" -eq 0 ] || [ "$status" -eq 124 ]
  [ ! -s "$FAKE_CURL_LOG" ]
  ! grep -q 'socksProxy' "$FAKE_JAVA_LOG"
}

@test "proxy: curl -x socks5 e flags java como argv unicos" {
  export SOCKS_PROXY_HOST="proxy.local"
  export SOCKS_PROXY_PORT="1080"
  rm -f "$APP_DIR/avctKVM.jar"
  run timeout 5 bash "$BATS_TEST_DIRNAME/../../startapp.sh"
  [ "$status" -eq 0 ] || [ "$status" -eq 124 ]
  grep -q "socks5://proxy.local:1080" "$FAKE_CURL_LOG"
  [ -f "$APP_DIR/avctKVM.jar" ]
  grep -Fx -- '-DsocksProxyHost=proxy.local' "$FAKE_JAVA_LOG"
  grep -Fx -- '-DsocksProxyPort=1080' "$FAKE_JAVA_LOG"
}

@test "secret: proxy via secrets sem env" {
  echo -n "proxy.local" > "$SECRETS_DIR/idrac_socks_proxy_host"
  echo -n "1080" > "$SECRETS_DIR/idrac_socks_proxy_port"
  rm -f "$APP_DIR/avctKVM.jar"
  run timeout 5 bash "$BATS_TEST_DIRNAME/../../startapp.sh"
  [ "$status" -eq 0 ] || [ "$status" -eq 124 ]
  grep -q "socks5://proxy.local:1080" "$FAKE_CURL_LOG"
  grep -Fx -- '-DsocksProxyHost=proxy.local' "$FAKE_JAVA_LOG"
}
