#!/usr/bin/env bats
# Integração: startapp.sh baixa os jars do mock HTTPS real (sem iDRAC físico).
# Usa wget REAL + fakes de java/jar/sleep. Limite conhecido: valida até
# `Initialization complete`; KVM real não é coberto (jars fake).

setup() {
  export T="$(mktemp -d)"
  export APP_DIR="$T/app"
  mkdir -p "$APP_DIR/lib"
  # fakes SEM wget: download precisa ser real contra o mock
  mkdir -p "$T/fakebin"
  ln -s "$BATS_TEST_DIRNAME/bin/java" "$T/fakebin/java"
  ln -s "$BATS_TEST_DIRNAME/bin/jar" "$T/fakebin/jar"
  ln -s "$BATS_TEST_DIRNAME/bin/sleep" "$T/fakebin/sleep"
  export PATH="$T/fakebin:/usr/bin:/bin"
  export FAKE_JAVA_LOG="$T/java.log"
  export FAKE_JAR_LOG="$T/jar.log"
  : > "$FAKE_JAVA_LOG"; : > "$FAKE_JAR_LOG"
  export MOCK_LOG="$T/mock.log"
  export MOCK_PORT=18443
  export IDRAC_HOST="localhost"
  export IDRAC_PORT="$MOCK_PORT"
  export IDRAC_USER="root"
  export IDRAC_PASSWORD="secret"
  export IDRAC_VNC_PORT="5900"
  export VIRTUAL_ISO=""
  sh "$BATS_TEST_DIRNAME/../mock-idrac/run.sh" --port "$MOCK_PORT" > "$MOCK_LOG" 2>&1 &
  echo $! > "$T/mock.pid"
  for _ in $(seq 1 50); do
    curl -k -s -o /dev/null "https://localhost:$MOCK_PORT/software/avctKVM.jar" && break
    sleep 0.2
  done
}

teardown() {
  jobs -p | xargs -r kill 2>/dev/null || true
  kill "$(cat "$T/mock.pid")" 2>/dev/null || true
  rm -rf "$T"
}

@test "integracao: baixa os 3 jars do mock e inicia console" {
  run timeout 20 bash "$BATS_TEST_DIRNAME/../../startapp.sh"
  [ "$status" -eq 0 ] || [ "$status" -eq 124 ]
  [ -f "$APP_DIR/avctKVM.jar" ]
  [ -f "$APP_DIR/lib/avctKVMIOLinux64.jar" ]
  [ -f "$APP_DIR/lib/avctVMLinux64.jar" ]
  grep -q '"GET /software/avctKVM.jar" 200' "$MOCK_LOG"
  grep -q '"GET /software/avctKVMIOLinux64.jar" 200' "$MOCK_LOG"
  grep -q '"GET /software/avctVMLinux64.jar" 200' "$MOCK_LOG"
  grep -q 'com.avocent.idrac.kvm.Main' "$FAKE_JAVA_LOG"
}
