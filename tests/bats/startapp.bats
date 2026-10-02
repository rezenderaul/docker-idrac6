#!/usr/bin/env bats
# Contract: fakes in bin/ record argv; startapp.sh must preserve quoting
# and try R710 fallback jars. Requires APP_DIR override (default /app).

setup() {
  export BATS_TMPDIR_TMP="$(mktemp -d)"
  export APP_DIR="$BATS_TMPDIR_TMP/app"
  mkdir -p "$APP_DIR/lib"
  export PATH="$BATS_TEST_DIRNAME/bin:$PATH"
  export FAKE_WGET_LOG="$BATS_TMPDIR_TMP/wget.log"
  export FAKE_JAVA_LOG="$BATS_TMPDIR_TMP/java.log"
  export FAKE_JAR_LOG="$BATS_TMPDIR_TMP/jar.log"
  export IDRAC_HOST="idrac.test"
  export IDRAC_PORT="443"
  export IDRAC_USER="root"
  : > "$FAKE_WGET_LOG"; : > "$FAKE_JAVA_LOG"; : > "$FAKE_JAR_LOG"
  export VIRTUAL_ISO=""
}

teardown() {
  # kill backgrounded fake java jobs from `exec java ... &` + wait
  jobs -p | xargs -r kill 2>/dev/null || true
  rm -rf "$BATS_TMPDIR_TMP"
}

@test "quoting: password com espaco e glob chega como argv unico" {
  export IDRAC_PASSWORD="a b*c"
  # pre-cria jars para pular downloads
  touch "$APP_DIR/avctKVM.jar" "$APP_DIR/lib/avctKVMIOLinux64.jar" "$APP_DIR/lib/avctVMLinux64.jar"
  mkdir -p "$APP_DIR/lib/lib"
  touch "$APP_DIR/lib/lib/avctKVMIOLinux64.so" "$APP_DIR/lib/lib/avctVMLinux64.so" 2>/dev/null || touch "$APP_DIR/lib/avctKVMIOLinux64.so" "$APP_DIR/lib/avctVMLinux64.so"
  run timeout 5 bash "$BATS_TEST_DIRNAME/../../startapp.sh"
  # script faz exec java & + wait; timeout estoura com 124, aceita 0 ou 124
  [ "$status" -eq 0 ] || [ "$status" -eq 124 ]
  grep -Fx 'passwd=a b*c' "$FAKE_JAVA_LOG"
}

@test "fallback: tenta avctKVMIOLinux.jar quando 64 falha (R710)" {
  export IDRAC_PASSWORD="secret"
  export FAKE_WGET_FAIL_PATTERN="avctKVMIOLinux64.jar"
  touch "$APP_DIR/avctKVM.jar" "$APP_DIR/lib/avctVMLinux64.jar"
  run timeout 5 bash "$BATS_TEST_DIRNAME/../../startapp.sh"
  [ "$status" -eq 0 ] || [ "$status" -eq 124 ]
  grep -q "avctKVMIOLinux64.jar" "$FAKE_WGET_LOG"
  grep -q "avctKVMIOLinux.jar" "$FAKE_WGET_LOG"
  [ -f "$APP_DIR/lib/avctKVMIOLinux.jar" ]
}
