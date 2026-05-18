#!/usr/bin/env sh
set -eu

REPO="LynkTechnology/MeetHermesRelease"
PACKAGE="hermes-platform-meet"
WORKDIR="${TMPDIR:-/tmp}/meet-hermes-install.$$"
VERSION="${1:-}"
CURL_RETRY_OPTS="--retry 3 --retry-delay 2 --connect-timeout 20 --max-time 300"

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "$2"
  fi
}

need_cmd curl "Please install curl first, then rerun this installer."
PYTHON="${MEET_HERMES_PYTHON:-python3}"
need_cmd "$PYTHON" "Please install Python 3.11+ first, then rerun this installer. Set MEET_HERMES_PYTHON=/path/to/python to install into a specific Hermes virtualenv."
need_cmd tar "Please install tar first, then rerun this installer."

if command -v shasum >/dev/null 2>&1; then
  SHA256_CMD="shasum -a 256 -c"
elif command -v sha256sum >/dev/null 2>&1; then
  SHA256_CMD="sha256sum -c"
else
  fail "Please install shasum or sha256sum first, then rerun this installer."
fi

latest_tag() {
  curl -fsSL $CURL_RETRY_OPTS "https://api.github.com/repos/${REPO}/releases/latest" \
    | "$PYTHON" -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])'
}

normalize_tag() {
  case "$1" in
    v*) printf '%s\n' "$1" ;;
    *) printf 'v%s\n' "$1" ;;
  esac
}

installed_version() {
  "$PYTHON" - <<'PY'
import importlib.metadata
try:
    print(importlib.metadata.version("hermes-platform-meet"))
except importlib.metadata.PackageNotFoundError:
    pass
PY
}

if [ -n "$VERSION" ]; then
  TAG="$(normalize_tag "$VERSION")"
else
  TAG="$(latest_tag)"
fi
TARGET_VERSION="${TAG#v}"
CURRENT_VERSION="$(installed_version)"

if [ -n "$CURRENT_VERSION" ]; then
  if [ "$CURRENT_VERSION" = "$TARGET_VERSION" ]; then
    log "MeetHermes ${CURRENT_VERSION} is already installed."
    if [ -z "$VERSION" ]; then
      exit 0
    fi
  elif [ -z "$VERSION" ]; then
    log "MeetHermes ${CURRENT_VERSION} is installed; updating to latest ${TARGET_VERSION}."
  else
    log "MeetHermes ${CURRENT_VERSION} is installed; installing requested ${TARGET_VERSION}."
  fi
fi

ARCHIVE="meet-hermes-wheelhouse-${TAG}.tar.gz"
CHECKSUM="meet-hermes-wheelhouse-${TAG}.sha256"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT INT TERM

log "Downloading MeetHermes ${TAG}..."
curl -fL $CURL_RETRY_OPTS "${BASE_URL}/${ARCHIVE}" -o "${WORKDIR}/${ARCHIVE}"
curl -fL $CURL_RETRY_OPTS "${BASE_URL}/${CHECKSUM}" -o "${WORKDIR}/${CHECKSUM}"

(
  cd "$WORKDIR"
  ${SHA256_CMD} "$CHECKSUM"
  tar -xzf "$ARCHIVE"
)

SDK_WHEEL="$(find "${WORKDIR}/wheelhouse" -name 'meet_python_sdk-*.whl' -type f | sort | tail -n 1)"
PLUGIN_WHEEL="$(find "${WORKDIR}/wheelhouse" -name 'hermes_platform_meet-*.whl' -type f | sort | tail -n 1)"
if [ -z "$SDK_WHEEL" ] || [ -z "$PLUGIN_WHEEL" ]; then
  fail "Release wheelhouse is missing MeetHermes wheels."
fi

log "Installing ${PACKAGE} ${TARGET_VERSION}..."
"$PYTHON" -m pip install --no-index --no-deps --upgrade "$SDK_WHEEL" "$PLUGIN_WHEEL"

if command -v hermes >/dev/null 2>&1; then
  hermes plugins enable meet || true
  if [ "${MEET_HERMES_RESTART_GATEWAY:-0}" = "1" ]; then
    hermes gateway restart || true
  else
    log "Restart the Hermes gateway to activate MeetHermes: hermes gateway restart"
  fi
else
  log "Hermes command not found in PATH. Enable the plugin after Hermes is available: hermes plugins enable meet"
fi

log "MeetHermes ${TARGET_VERSION} installed."
