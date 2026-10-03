#!/usr/bin/env bats
# Contrato kvm-ports: IDRAC_VNC_PORT chega a kmport=/vport= como argv únicos.
# Usa fakes de wget/java/jar/sleep; APP_DIR/SECRETS_DIR sobrescrevíveis.

setup() {
  export BATS_TMPDIR_TMP="$(mktemp -d)"
  export APP_DIR="$BATS_TMPDIR_TMP/app"
  mkdir -p "$APP_DIR/lib"
  export SECRETS_DIR="$BATS_TMPDIR_TMP/secrets"
  mkdir -p "$SECRETS_DIR"
  export PATH="$BATS_TEST_DIRNAME/bin:$PATH"
  export FAKE_WGET_LOG="$BATS_TMPDIR_TMP/wget.log"
  export FAKE_JAVA_LOG="$BATS_TMPDIR_TMP/java.log"
  export FAKE_JAR_LOG="$BATS_TMPDIR_TMP/jar.log"
  export IDRAC_HOST="idrac.test"
  export IDRAC_PORT="443"
  export IDRAC_USER="root"
  export IDRAC_PASSWORD="secret"
  : > "$FAKE_WGET_LOG"; : > "$FAKE_JAVA_LOG"; : > "$FAKE_JAR_LOG"
  export VIRTUAL_ISO=""
  touch "$APP_DIR/avctKVM.jar" "$APP_DIR/lib/avctKVMIOLinux64.jar" "$APP_DIR/lib/avctVMLinux64.jar"
}

teardown() {
  jobs -p | xargs -r kill 2>/dev/null || true
  rm -rf "$BATS_TMPDIR_TMP"
}

@test "default: kmport/vport 5900" {
  export IDRAC_VNC_PORT="5900"
  run timeout 5 bash "$BATS_TEST_DIRNAME/../../startapp.sh"
  [ "$status" -eq 0 ] || [ "$status" -eq 124 ]
  grep -Fx 'kmport=5900' "$FAKE_JAVA_LOG"
  grep -Fx 'vport=5900' "$FAKE_JAVA_LOG"
}

@test "custom: kmport/vport 5999 como argv unico" {
  export IDRAC_VNC_PORT="5999"
  run timeout 5 bash "$BATS_TEST_DIRNAME/../../startapp.sh"
  [ "$status" -eq 0 ] || [ "$status" -eq 124 ]
  grep -Fx 'kmport=5999' "$FAKE_JAVA_LOG"
  grep -Fx 'vport=5999' "$FAKE_JAVA_LOG"
}

@test "secret: idrac_vnc_port sem env" {
  unset IDRAC_VNC_PORT
  echo -n "5998" > "$SECRETS_DIR/idrac_vnc_port"
  run timeout 5 bash "$BATS_TEST_DIRNAME/../../startapp.sh"
  [ "$status" -eq 0 ] || [ "$status" -eq 124 ]
  grep -Fx 'kmport=5998' "$FAKE_JAVA_LOG"
  grep -Fx 'vport=5998' "$FAKE_JAVA_LOG"
}
