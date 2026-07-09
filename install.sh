#!/usr/bin/env sh
set -eu

REPO="LynkTechnology/MeetHermesRelease"
PACKAGE="hermes-platform-meet"
PLUGIN_NAME="platforms/meet"
HERMES_HOME_DIR="${HERMES_HOME:-${HOME}/.hermes}"
PLUGIN_DIR="${HERMES_HOME_DIR}/plugins/${PLUGIN_NAME}"
WORKDIR="${TMPDIR:-/tmp}/meet-hermes-install.$$"
VERSION=""
PROFILE_NAME=""
PROFILE_SCOPE_REQUESTED="0"
CURL_RETRY_OPTS="--retry 3 --retry-delay 2 --connect-timeout 20 --max-time 300"

usage() {
  cat <<'EOF'
Usage: install.sh [--profile <profile>] [--all] [version]

Install or update MeetHermes for every Hermes profile including default, or
for one named profile when --profile is provided.

Options:
  --profile <profile>  Install the plugin shim into one Hermes profile.
                       Use "default" for the root Hermes home.
  --all                Compatibility option. This is now the default behavior.
  -h, --help           Show this help.

Environment:
  HERMES_HOME          Hermes home directory. Defaults to ~/.hermes.
  MEET_HERMES_PYTHON  Python interpreter to install into. Defaults to
                      ~/.hermes/hermes-agent/venv/bin/python3 when present,
                      otherwise python3 from PATH.
EOF
}

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

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      if [ "$#" -lt 2 ] || [ "${2#-}" != "$2" ]; then
        fail "--profile requires a profile name."
      fi
      PROFILE_NAME="$2"
      shift 2
      ;;
    --all)
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      usage >&2
      fail "Unknown argument: $1"
      ;;
    *)
      if [ -n "$VERSION" ]; then
        usage >&2
        fail "Only one version may be provided."
      fi
      VERSION="$1"
      shift
      ;;
  esac
done

if [ -n "$PROFILE_NAME" ]; then
  PROFILE_SCOPE_REQUESTED="1"
fi

profile_plugin_dir() {
  profile="$1"
  if [ "$profile" = "default" ]; then
    printf '%s\n' "${HERMES_HOME_DIR}/plugins/${PLUGIN_NAME}"
  else
    printf '%s\n' "${HERMES_HOME_DIR}/profiles/${profile}/plugins/${PLUGIN_NAME}"
  fi
}

profile_names() {
  printf '%s\n' default
  profiles_dir="${HERMES_HOME_DIR}/profiles"
  if [ -d "$profiles_dir" ]; then
    for profile_dir in "$profiles_dir"/*; do
      [ -d "$profile_dir" ] || continue
      printf '%s\n' "${profile_dir##*/}"
    done
  fi
}

need_cmd curl "Please install curl first, then rerun this installer."
HERMES_AGENT_PYTHON="${HOME}/.hermes/hermes-agent/venv/bin/python3"
if [ -n "${MEET_HERMES_PYTHON:-}" ]; then
  PYTHON="$MEET_HERMES_PYTHON"
elif [ -x "$HERMES_AGENT_PYTHON" ]; then
  PYTHON="$HERMES_AGENT_PYTHON"
else
  PYTHON="python3"
fi
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

install_wheels_with_python() {
  "$PYTHON" - "$SDK_WHEEL" "$PLUGIN_WHEEL" <<'PY'
import glob
import shutil
import sys
import sysconfig
import zipfile
from pathlib import Path

site_packages = Path(sysconfig.get_paths()["purelib"])
site_packages.mkdir(parents=True, exist_ok=True)

def remove_existing(name):
    target = site_packages / name
    if target.exists():
        if target.is_dir():
            shutil.rmtree(target)
        else:
            target.unlink()
    for dist_info in glob.glob(str(site_packages / f"{name.replace('_', '-')}-*.dist-info")):
        shutil.rmtree(dist_info, ignore_errors=True)
    for dist_info in glob.glob(str(site_packages / f"{name}-*.dist-info")):
        shutil.rmtree(dist_info, ignore_errors=True)

remove_existing("meet_sdk")
remove_existing("meet_python_sdk")
remove_existing("hermes_platform_meet")

for wheel in sys.argv[1:]:
    with zipfile.ZipFile(wheel) as archive:
        archive.extractall(site_packages)

import importlib.metadata
entry_points = importlib.metadata.entry_points()
if hasattr(entry_points, "select"):
    plugins = entry_points.select(group="hermes_agent.plugins", name="meet")
else:
    plugins = [
        ep for ep in entry_points.get("hermes_agent.plugins", [])
        if ep.name == "meet"
    ]
if not plugins:
    raise SystemExit("Installed wheel metadata is missing hermes_agent.plugins entry point 'meet'.")
PY
}

install_hermes_directory_plugin() {
  target="$1"
  "$PYTHON" - "$PLUGIN_WHEEL" "$target" "$TARGET_VERSION" <<'PY'
import shutil
import sys
import zipfile
from pathlib import Path

wheel = Path(sys.argv[1])
plugin_dir = Path(sys.argv[2])
version = sys.argv[3]

plugin_dir.parent.mkdir(parents=True, exist_ok=True)
if plugin_dir.exists():
    shutil.rmtree(plugin_dir)
plugin_dir.mkdir(parents=True)

with zipfile.ZipFile(wheel) as archive:
    manifest = archive.read("hermes_platform_meet/plugin.yaml").decode("utf-8")

plugin_dir.joinpath("plugin.yaml").write_text(manifest, encoding="utf-8")
plugin_dir.joinpath("__init__.py").write_text(
    "from __future__ import annotations\n\n"
    "from hermes_platform_meet import check_requirements, register\n\n"
    "__all__ = [\"check_requirements\", \"register\"]\n",
    encoding="utf-8",
)
plugin_dir.joinpath("VERSION").write_text(f"{version}\n", encoding="utf-8")
PY
}

enable_profile_plugin() {
  profile="$1"
  if command -v hermes >/dev/null 2>&1; then
    if [ "$profile" = "default" ]; then
      hermes plugins enable "$PLUGIN_NAME" --no-allow-tool-override
    else
      hermes --profile "$profile" plugins enable "$PLUGIN_NAME" --no-allow-tool-override
    fi

    if [ "${MEET_HERMES_RESTART_GATEWAY:-1}" = "0" ]; then
      if [ "$profile" = "default" ]; then
        log "Restart the Hermes gateway to activate MeetHermes: hermes gateway restart"
      else
        log "Restart the Hermes gateway to activate MeetHermes for profile ${profile}: hermes --profile ${profile} gateway restart"
      fi
    elif [ "$profile" = "default" ]; then
      hermes gateway restart || true
    else
      hermes --profile "$profile" gateway restart || true
    fi
  else
    if [ "$profile" = "default" ]; then
      log "Hermes command not found in PATH. Enable the plugin after Hermes is available: hermes plugins enable ${PLUGIN_NAME} --no-allow-tool-override"
    else
      log "Hermes command not found in PATH. Enable the plugin after Hermes is available: hermes --profile ${profile} plugins enable ${PLUGIN_NAME} --no-allow-tool-override"
    fi
  fi
}

install_profile_plugin() {
  profile="$1"
  target="$(profile_plugin_dir "$profile")"
  log "Installing Hermes directory plugin to ${target}..."
  install_hermes_directory_plugin "$target"
  enable_profile_plugin "$profile"
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
    if [ -z "$VERSION" ] && [ -n "$PROFILE_NAME" ]; then
      log "MeetHermes ${CURRENT_VERSION} is already installed."
      exit 0
    else
      log "MeetHermes ${CURRENT_VERSION} is already installed; installing profile plugin shim."
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
if "$PYTHON" -m pip --version >/dev/null 2>&1; then
  "$PYTHON" -m pip install --no-index --no-deps --upgrade "$SDK_WHEEL" "$PLUGIN_WHEEL"
else
  log "pip is unavailable; installing wheels with Python zip extraction."
  install_wheels_with_python
fi
if [ -n "$PROFILE_NAME" ]; then
  install_profile_plugin "$PROFILE_NAME"
else
  profile_names | while IFS= read -r profile; do
    install_profile_plugin "$profile"
  done
fi

log "MeetHermes ${TARGET_VERSION} installed."
