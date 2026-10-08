#!/usr/bin/env sh
set -eu

REPO="LynkTechnology/MeetHermesRelease"
HERMES_HOME_DIR="${HERMES_HOME:-${HOME}/.hermes}"
PROFILE_NAME=""
VERSION=""
CURL_RETRY_OPTS="--retry 3 --retry-delay 2 --connect-timeout 20 --max-time 300"

usage() {
  cat <<'EOF'
Usage: install.sh [--profile <profile>] [--all] [version]

Install or update MeetHermes using Hermes >=0.21.5's managed Python runtime.
Defaults to all existing profiles, including default.

Options:
  --profile <profile>  Install only one existing profile; default selects root.
  --all                Install all profiles (the default).

Environment:
  HERMES_HOME                  Root Hermes home (defaults to ~/.hermes).
  MEET_HERMES_RESTART_GATEWAY   Set to 0 to skip the gateway restart.
EOF
}
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "$2"; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      [ "$#" -ge 2 ] && [ "${2#-}" = "$2" ] || fail "--profile requires a profile name."
      PROFILE_NAME="$2"; shift 2 ;;
    --all) shift ;;
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; fail "Unknown argument: $1" ;;
    *) [ -z "$VERSION" ] || fail "Only one version may be provided."; VERSION="${1#v}"; shift ;;
  esac
done
need_cmd hermes "Please install Hermes >=0.21.5 first."
need_cmd curl "Please install curl first."
need_cmd tar "Please install tar first."
need_cmd python3 "Please install python3 for the launcher bootstrap."
if command -v shasum >/dev/null 2>&1; then
  SHA256_CMD="shasum -a 256 -c"
elif command -v sha256sum >/dev/null 2>&1; then
  SHA256_CMD="sha256sum -c"
else
  fail "Please install shasum or sha256sum first."
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/meet-hermes-install.XXXXXXXX")"
trap 'rm -rf "$WORKDIR"' 0
if [ -z "$VERSION" ]; then
  curl -fsSL $CURL_RETRY_OPTS "https://api.github.com/repos/${REPO}/releases/latest" > "$WORKDIR/latest.json"
  hermes --run-module json.tool < "$WORKDIR/latest.json" > "$WORKDIR/latest-formatted.json"
  TAG="$(awk -F '"' '/^[[:space:]]*"tag_name":/ {print $4; exit}' "$WORKDIR/latest-formatted.json")"
  VERSION="${TAG#v}"
fi
case "$VERSION" in
  ''|*[!0-9.]*) fail "Invalid release version: $VERSION" ;;
esac
TAG="v${VERSION}"
ARCHIVE="meet-hermes-wheelhouse-${TAG}.tar.gz"
CHECKSUM="meet-hermes-wheelhouse-${TAG}.sha256"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
printf 'Downloading MeetHermes %s...\n' "$TAG"
curl -fL $CURL_RETRY_OPTS "${BASE_URL}/${ARCHIVE}" -o "${WORKDIR}/${ARCHIVE}"
curl -fL $CURL_RETRY_OPTS "${BASE_URL}/${CHECKSUM}" -o "${WORKDIR}/${CHECKSUM}"
(
  cd "$WORKDIR"
  ${SHA256_CMD} "$CHECKSUM"
  tar -xzf "$ARCHIVE"
)
[ -f "$WORKDIR/install_runtime.py" ] || fail "Release is missing the Hermes PM installer. Use MeetHermes >=0.8.0."
set -- --wheelhouse "$WORKDIR/wheelhouse" --home "$HERMES_HOME_DIR" --version "$VERSION"
if [ -n "$PROFILE_NAME" ]; then
  set -- "$@" --profile "$PROFILE_NAME"
fi
python3 "$WORKDIR/install_runtime.py" "$@"
