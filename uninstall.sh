#!/usr/bin/env sh
set -eu

PLUGIN_NAME="platforms/meet"
HERMES_HOME_DIR="${HERMES_HOME:-${HOME}/.hermes}"
PLUGIN_DIR="${HERMES_HOME_DIR}/plugins/${PLUGIN_NAME}"
PROFILE_NAME=""
UNINSTALL_ALL_PROFILES="0"

usage() {
  cat <<'EOF'
Usage: uninstall.sh [--profile <profile>|--all]

Remove MeetHermes from the default Hermes profile, a named profile, or every
profile including default. Python packages are removed once from the selected
Hermes Python environment.

Options:
  --profile <profile>  Remove the plugin shim from one Hermes profile.
                       Use "default" for the root Hermes home.
  --all                Remove the plugin shim from default and all profiles
                       under $HERMES_HOME/profiles.
  -h, --help           Show this help.

Environment:
  HERMES_HOME          Hermes home directory. Defaults to ~/.hermes.
  MEET_HERMES_PYTHON  Python interpreter to uninstall from. Defaults to
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
      UNINSTALL_ALL_PROFILES="1"
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
      usage >&2
      fail "Unknown argument: $1"
      ;;
  esac
done

if [ -n "$PROFILE_NAME" ] && [ "$UNINSTALL_ALL_PROFILES" = "1" ]; then
  fail "--profile and --all cannot be used together."
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

HERMES_AGENT_PYTHON="${HOME}/.hermes/hermes-agent/venv/bin/python3"
if [ -n "${MEET_HERMES_PYTHON:-}" ]; then
  PYTHON="$MEET_HERMES_PYTHON"
elif [ -x "$HERMES_AGENT_PYTHON" ]; then
  PYTHON="$HERMES_AGENT_PYTHON"
else
  PYTHON="python3"
fi
need_cmd "$PYTHON" "Please install Python 3 first, then rerun this uninstaller. Set MEET_HERMES_PYTHON=/path/to/python to uninstall from a specific Hermes virtualenv."

uninstall_with_python() {
  "$PYTHON" - <<'PY'
import glob
import shutil
import sysconfig
from pathlib import Path

site_packages = Path(sysconfig.get_paths()["purelib"])

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
PY
}

disable_profile_plugin() {
  profile="$1"
  if command -v hermes >/dev/null 2>&1; then
    if [ "$profile" = "default" ]; then
      hermes plugins disable "$PLUGIN_NAME" || true
    else
      hermes --profile "$profile" plugins disable "$PLUGIN_NAME" || true
    fi
  fi
}

restart_profile_gateway() {
  profile="$1"
  if command -v hermes >/dev/null 2>&1; then
    if [ "${MEET_HERMES_RESTART_GATEWAY:-0}" = "1" ]; then
      if [ "$profile" = "default" ]; then
        hermes gateway restart || true
      else
        hermes --profile "$profile" gateway restart || true
      fi
    else
      if [ "$profile" = "default" ]; then
        log "Restart the Hermes gateway to finish removing MeetHermes: hermes gateway restart"
      else
        log "Restart the Hermes gateway to finish removing MeetHermes for profile ${profile}: hermes --profile ${profile} gateway restart"
      fi
    fi
  fi
}

uninstall_hermes_directory_plugin() {
  target="$1"
  rm -rf "$target"
}

uninstall_profile_plugin() {
  profile="$1"
  target="$(profile_plugin_dir "$profile")"
  disable_profile_plugin "$profile"
  uninstall_hermes_directory_plugin "$target"
}

if [ "$UNINSTALL_ALL_PROFILES" = "1" ]; then
  profile_names | while IFS= read -r profile; do
    uninstall_profile_plugin "$profile"
  done
else
  uninstall_profile_plugin "${PROFILE_NAME:-default}"
fi

if "$PYTHON" -m pip --version >/dev/null 2>&1; then
  "$PYTHON" -m pip uninstall -y hermes-platform-meet meet-python-sdk
else
  log "pip is unavailable; removing MeetHermes packages with Python filesystem cleanup."
  uninstall_with_python
fi

if [ "$UNINSTALL_ALL_PROFILES" = "1" ]; then
  profile_names | while IFS= read -r profile; do
    restart_profile_gateway "$profile"
  done
else
  restart_profile_gateway "${PROFILE_NAME:-default}"
fi

log "MeetHermes uninstalled."
