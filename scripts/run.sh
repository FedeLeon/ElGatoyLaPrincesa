#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--low" ]]; then
  export GATO_3D_SCALE="${GATO_3D_SCALE:-0.7}"
  shift
fi

if [[ -n "${GODOT_BIN:-}" ]]; then
  godot_bin="$GODOT_BIN"
elif [[ -x .tools/godot ]]; then
  godot_bin="$PWD/.tools/godot"
elif [[ -x .tools/Godot_v4.5.2-stable_linux.x86_64 ]]; then
  godot_bin="$PWD/.tools/Godot_v4.5.2-stable_linux.x86_64"
elif [[ -x "$HOME/.local/bin/godot4" ]]; then
  godot_bin="$HOME/.local/bin/godot4"
elif command -v godot4 >/dev/null 2>&1; then
  godot_bin="$(command -v godot4)"
elif command -v godot >/dev/null 2>&1; then
  godot_bin="$(command -v godot)"
else
  cat >&2 <<'EOF'
No encuentro Godot 4.
Instalá Godot y agregalo al PATH, guardalo como .tools/godot,
o indicá su ruta con GODOT_BIN. Ejemplo:
  GODOT_BIN=/ruta/a/Godot ./scripts/run.sh
EOF
  exit 1
fi

# Keep explicitly selected drivers and non-windowed technical commands intact.
gato_window=true
gato_driver=false
for gato_argument in "$@"; do
  case "$gato_argument" in
    --) break ;;
    --headless|--editor|--export-*|--version|--help|-h|--check-only) gato_window=false ;;
    --display-driver|--display-driver=*) gato_driver=true ;;
  esac
done
gato_platform_args=()
if [[ -n "${WAYLAND_DISPLAY:-}" && "$gato_window" == true && "$gato_driver" == false ]]; then
  if [[ -n "${DISPLAY:-}" ]]; then
    # XWayland delegates title-bar buttons and resizing to the desktop window manager.
    gato_platform_args+=(--display-driver x11)
  else
    gato_platform_args+=(--display-driver wayland)
  fi
fi

exec "$godot_bin" --path . "${gato_platform_args[@]}" "$@"
