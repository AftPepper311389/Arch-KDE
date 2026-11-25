#!/usr/bin/env bash
set -Eeuo pipefail

# Run inside an Arch Linux ARM64 RootFS as root (for example via proot).
# This prepares Plasma + KWin + Wayland; it does not create the RootFS itself.

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "ERROR: expected native ARM64 userspace (aarch64), got $(uname -m)" >&2
  exit 2
fi
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: run this script as root inside the Arch RootFS" >&2
  exit 2
fi
if ! command -v pacman >/dev/null 2>&1; then
  echo "ERROR: pacman not found; this is not an Arch Linux RootFS" >&2
  exit 2
fi

export LANG=C
install -d -m 0755 /etc/pacman.d
if [[ ! -s /etc/pacman.d/mirrorlist ]]; then
  cat > /etc/pacman.d/mirrorlist <<'MIRRORS'
Server = https://mirror.archlinuxarm.org/$arch/$repo
MIRRORS
fi

# Initialize the Arch Linux ARM keyring before the full system upgrade.
pacman-key --init
pacman-key --populate archlinuxarm
pacman -Syy --noconfirm archlinuxarm-keyring
pacman -Syu --noconfirm

# Plasma + KWin Wayland compositor, Qt Wayland, desktop utilities and D-Bus.
# XWayland is compatibility only; it is not the desktop display server.
pacman -S --needed --noconfirm \
  plasma-desktop plasma-workspace kwin \
  wayland wayland-protocols qt6-wayland \
  xorg-xwayland \
  dbus dbus-broker \
  dolphin konsole kate ark \
  breeze breeze-gtk \
  xdg-user-dirs xdg-utils xdg-desktop-portal xdg-desktop-portal-kde \
  polkit kscreen libinput \
  mesa mesa-utils vulkan-icd-loader vulkan-tools \
  pipewire pipewire-pulse wireplumber \
  ttf-dejavu noto-fonts noto-fonts-cjk

# Install optional Qualcomm userspace drivers only when available in configured
# Arch Linux ARM repositories. Do not fail the base desktop if a device-specific
# package is absent; the runtime must probe the actual GPU before selecting it.
if pacman -Si mesa | grep -q '^Repository'; then
  pacman -S --needed --noconfirm mesa
fi

install -d -m 0700 /run/user/1000
install -d -m 0755 /etc/profile.d
cat > /etc/profile.d/arch-kde-wayland.sh <<'PROFILE'
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export MOZ_ENABLE_WAYLAND=1
export SDL_VIDEODRIVER=wayland
PROFILE

cat > /usr/local/bin/arch-kde-wayland-session <<'SESSION'
#!/usr/bin/env bash
set -Eeuo pipefail
uid="$(id -u)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$uid}"
install -d -m 0700 "$XDG_RUNTIME_DIR"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export MOZ_ENABLE_WAYLAND=1

# PRoot does not provide systemd-logind/DRM seats. KWin must be built/configured
# with a supported nested or Android-backed output backend by the app port.
if ! command -v kwin_wayland >/dev/null 2>&1; then
  echo "kwin_wayland is missing" >&2
  exit 127
fi
if [[ -z "${WAYLAND_DISPLAY_BACKEND_READY:-}" ]]; then
  echo "No Android Wayland output backend was announced." >&2
  echo "Refusing to start a session that would only produce a black screen." >&2
  exit 78
fi
exec dbus-run-session startplasma-wayland
SESSION
chmod 0755 /usr/local/bin/arch-kde-wayland-session

cat > /etc/os-release.arch-kde <<'OS'
NAME="Arch Linux ARM (KDE Plasma)"
ID=arch
ID_LIKE=arch
PRETTY_NAME="Arch Linux ARM with KDE Plasma"
OS
echo "Arch KDE/Wayland packages installed."
echo "NOTE: Android Surface output backend and GPU acceleration still require device-side integration and validation."
