#!/usr/bin/env bash
set -Eeuo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

[[ "$(uname -m)" == "aarch64" ]] || fail "userspace is not native aarch64"
command -v pacman >/dev/null 2>&1 || fail "pacman is missing"
command -v kwin_wayland >/dev/null 2>&1 || fail "KWin Wayland compositor is missing"
command -v startplasma-wayland >/dev/null 2>&1 || fail "Plasma Wayland session is missing"
command -v dbus-run-session >/dev/null 2>&1 || fail "dbus-run-session is missing"
command -v eglinfo >/dev/null 2>&1 || fail "eglinfo is missing (mesa-utils)"
pass "Arch ARM64 + KDE Wayland runtime packages"

[[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] || fail "XDG_SESSION_TYPE must be wayland"
[[ "${XDG_RUNTIME_DIR:-}" == /* ]] || fail "XDG_RUNTIME_DIR must be an absolute path"
[[ -d "$XDG_RUNTIME_DIR" ]] || fail "XDG_RUNTIME_DIR does not exist"
[[ -O "$XDG_RUNTIME_DIR" ]] || fail "XDG_RUNTIME_DIR is not owned by current uid"
[[ -S "$XDG_RUNTIME_DIR/${WAYLAND_DISPLAY:-wayland-0}" ]] || fail "Wayland socket is not present"
pass "Wayland runtime directory and socket"

renderer="$(eglinfo -B 2>/dev/null | grep -m1 -E 'Device:|OpenGL renderer string:' || true)"
[[ -n "$renderer" ]] || fail "EGL renderer could not be identified"
case "$renderer" in
  *llvmpipe*|*softpipe*|*swrast*|*lavapipe*)
    fail "software renderer detected: $renderer"
    ;;
esac
pass "EGL renderer reported: $renderer"

if [[ -e /dev/kgsl-3d0 ]]; then
  pass "Qualcomm KGSL device node detected"
elif [[ -e /dev/dri/renderD128 ]]; then
  pass "DRM render node detected"
else
  echo "WARN: no KGSL or DRM render node visible; hardware acceleration cannot be confirmed"
fi

if command -v vulkaninfo >/dev/null 2>&1; then
  if vulkaninfo --summary 2>/dev/null | grep -qiE 'turnip|freedreno|adreno'; then
    pass "Qualcomm Vulkan device/driver detected"
  else
    echo "WARN: Vulkan device is not identified as Turnip/Freedreno/Adreno"
  fi
else
  echo "WARN: vulkaninfo is unavailable; Vulkan acceleration not verified"
fi
