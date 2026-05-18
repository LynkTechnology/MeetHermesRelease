#!/usr/bin/env sh
set -eu

PLUGIN_NAME="platforms/meet"
HERMES_HOME_DIR="${HERMES_HOME:-${HOME}/.hermes}"
PLUGIN_DIR="${HERMES_HOME_DIR}/plugins/${PLUGIN_NAME}"

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

if command -v hermes >/dev/null 2>&1; then
  hermes plugins disable "$PLUGIN_NAME" || true
fi

rm -rf "$PLUGIN_DIR"

if "$PYTHON" -m pip --version >/dev/null 2>&1; then
  "$PYTHON" -m pip uninstall -y hermes-platform-meet meet-python-sdk
else
  log "pip is unavailable; removing MeetHermes packages with Python filesystem cleanup."
  uninstall_with_python
fi

if command -v hermes >/dev/null 2>&1; then
  if [ "${MEET_HERMES_RESTART_GATEWAY:-0}" = "1" ]; then
    hermes gateway restart || true
  else
    log "Restart the Hermes gateway to finish removing MeetHermes: hermes gateway restart"
  fi
fi

log "MeetHermes uninstalled."
