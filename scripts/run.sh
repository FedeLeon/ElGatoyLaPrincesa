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
  # Native Wayland uses the GPU selected by this desktop; XWayland fell back
  # to llvmpipe on this machine and made the 3D scene render on the CPU.
  gato_platform_args+=(--display-driver wayland)
  # This GNOME install has a libdecor plugin that crashes when its xsettings
  # schema lacks the antialiasing key. Use Godot's undecorated fallback there.
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && command -v gsettings >/dev/null 2>&1; then
    gato_schema_keys="$(gsettings list-keys org.gnome.settings-daemon.plugins.xsettings 2>/dev/null || true)"
    if [[ "$gato_schema_keys" != *antialiasing* ]]; then
      gato_decor_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ElGatoyLaPrincesa/no-decor"
      mkdir -p "$gato_decor_dir"
      export LIBDECOR_PLUGIN_DIR="$gato_decor_dir"
    fi
  fi
fi

# Godot needs its imported texture and font cache before launching the game.
# Generate it once on a fresh checkout, or after the pixel assets are added.
if [[ "$gato_window" == true ]] && {
  ! compgen -G '.godot/imported/PixelifySans.ttf-*.fontdata' >/dev/null ||
  ! compgen -G '.godot/imported/pixel_forest_floor.png-*.ctex' >/dev/null ||
  ! compgen -G '.godot/imported/pixel_forest_path.png-*.ctex' >/dev/null ||
  ! compgen -G '.godot/imported/pixel_princess_walk_sheet.png-*.ctex' >/dev/null ||
  ! compgen -G '.godot/imported/pixel_stairs.png-*.ctex' >/dev/null ||
  ! compgen -G '.godot/imported/title_forest_pixel_v2.png-*.ctex' >/dev/null;
}; then
  printf '%s\n' 'Preparando los recursos del juego por primera vez…'
  "$godot_bin" --headless --editor --path . --quit
fi

exec "$godot_bin" --path . "${gato_platform_args[@]}" "$@"
