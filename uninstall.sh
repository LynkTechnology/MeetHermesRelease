#!/usr/bin/env sh
set -eu

HERMES_HOME_DIR="${HERMES_HOME:-${HOME}/.hermes}"
PROFILE_NAME="default"
ALL_PROFILES="0"
PROFILE_SELECTED="0"

usage() {
  cat <<'EOF'
Usage: uninstall.sh [--profile <profile>|--all]

Remove MeetHermes using Hermes' plugin and dependency management.
The shared wheel cache is retained for other profiles and future reinstalls.

Environment:
  HERMES_HOME                  Root Hermes home (defaults to ~/.hermes).
  MEET_HERMES_RESTART_GATEWAY   Set to 1 to restart after removal.
EOF
}
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      [ "$#" -ge 2 ] && [ "${2#-}" = "$2" ] || fail "--profile requires a profile name."
      PROFILE_NAME="$2"; PROFILE_SELECTED="1"; shift 2 ;;
    --all) ALL_PROFILES="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; fail "Unknown argument: $1" ;;
  esac
done
[ "$PROFILE_SELECTED" != "1" ] || [ "$ALL_PROFILES" != "1" ] || fail "--profile and --all cannot be used together."
case "$PROFILE_NAME" in
  ''|.|..|*/*|*\\*) fail "Invalid profile name." ;;
esac
command -v hermes >/dev/null 2>&1 || fail "Please install Hermes >=0.21.5 first."
export HERMES_HOME="$HERMES_HOME_DIR"

remove_profile() {
  profile="$1"
  if [ "$profile" = "default" ]; then
    target="$HERMES_HOME_DIR/plugins/platforms/meet"
  else
    target="$HERMES_HOME_DIR/profiles/$profile/plugins/platforms/meet"
  fi
  [ -d "$target" ] || return 0
  # disable performs PM admission for the remaining enabled profiles first.
  hermes --profile "$profile" plugins disable platforms/meet
  hermes --profile "$profile" plugins remove platforms/meet
}
if [ "$ALL_PROFILES" = "1" ]; then
  remove_profile default
  for directory in "$HERMES_HOME_DIR"/profiles/*; do
    [ -d "$directory" ] && [ ! -L "$directory" ] || continue
    remove_profile "${directory##*/}"
  done
else
  remove_profile "$PROFILE_NAME"
fi
if [ "${MEET_HERMES_RESTART_GATEWAY:-0}" = "1" ]; then
  if [ "$ALL_PROFILES" = "1" ]; then PROFILE_NAME="default"; fi
  hermes --profile "$PROFILE_NAME" gateway restart
else
  printf 'Restart the gateway to finish removing MeetHermes: hermes --profile %s gateway restart\n' "$PROFILE_NAME"
fi
printf 'MeetHermes removed from the selected profile(s). Shared wheels retained.\n'
