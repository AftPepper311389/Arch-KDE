#!/usr/bin/env bash
set -euo pipefail

# Build an ARM64 Arch Linux ARM rootfs on a native aarch64 Linux runner.
# The resulting tarball is consumed as an Android asset by the APK build.
ROOT="${1:-$PWD/app/src/main/assets/rootfs}"
WORK="${RUNNER_TEMP:-/tmp}/archlinuxarm-rootfs"
ARCHIVE="${RUNNER_TEMP:-/tmp}/ArchLinuxARM-aarch64-latest.tar.gz"
SIG="$ARCHIVE.sig"
KEY_ID="68B3537F39A313B3E574D06777193F152BDBE6A6"
URL="https://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"

test "$(uname -m)" = "aarch64" || { echo "This rootfs builder must run on native aarch64." >&2; exit 2; }
command -v bsdtar >/dev/null
command -v gpg >/dev/null
command -v pacman >/dev/null || true

mkdir -p "$ROOT"
curl --fail --location --retry 5 --retry-all-errors "$URL" -o "$ARCHIVE"
curl --fail --location --retry 5 --retry-all-errors "$URL.sig" -o "$SIG"

gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "$KEY_ID"
ACTUAL_FPR="$(gpg --batch --with-colons --fingerprint "$KEY_ID" | awk -F: '$1=="fpr"{print $10; exit}')"
test "$ACTUAL_FPR" = "$KEY_ID" || { echo "Unexpected Arch Linux ARM signing key fingerprint: $ACTUAL_FPR" >&2; exit 3; }
gpg --batch --verify "$SIG" "$ARCHIVE"

rm -rf "$WORK"
mkdir -p "$WORK"
bsdtar -xpf "$ARCHIVE" -C "$WORK"

# Keep the upstream ARMv8 userspace, but remove device-specific boot payloads.
rm -rf "$WORK/boot" "$WORK/dev" "$WORK/proc" "$WORK/sys" "$WORK/run"
mkdir -p "$WORK"/{dev,proc,sys,run,tmp}
chmod 1777 "$WORK/tmp"

# Set the ARM package mirror and configure a non-device-specific container.
cat > "$WORK/etc/hostname" <<'EOF'
arch-kde
EOF
cat > "$WORK/etc/resolv.conf" <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# Initialize signing keys and install the desktop/compositor stack inside the
# rootfs on native ARM64. The Android app still needs a separate display bridge.
mount --bind /dev "$WORK/dev"
mount --bind /dev/pts "$WORK/dev/pts"
mount -t proc proc "$WORK/proc"
mount -t sysfs sysfs "$WORK/sys"
cleanup() {
  umount -lf "$WORK/dev/pts" 2>/dev/null || true
  umount -lf "$WORK/dev" 2>/dev/null || true
  umount -lf "$WORK/proc" 2>/dev/null || true
  umount -lf "$WORK/sys" 2>/dev/null || true
}
trap cleanup EXIT

chroot "$WORK" /bin/bash -euc '
  pacman-key --init
  pacman-key --populate archlinuxarm
  pacman -Syy --noconfirm
  pacman -Syu --noconfirm --needed \
    base sudo bash coreutils util-linux procps-ng iproute2 iputils \
    dbus polkit seatd \
    plasma-desktop plasma-workspace kwin wayland wayland-protocols \
    qt6-wayland xorg-xwayland \
    mesa libglvnd vulkan-icd-loader \
    konsole dolphin ark plasma-nm plasma-pa \
    noto-fonts noto-fonts-cjk ttf-dejavu \
    git python python-pip base-devel fastfetch
  pacman -Scc --noconfirm
  rm -rf /var/cache/pacman/pkg/*
  rm -rf /var/log/*
  rm -f /etc/machine-id
  touch /etc/machine-id
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  getent group wheel >/dev/null || groupadd wheel
  printf "root:archlinuxarm\n" | chpasswd
'

# Preserve permissions and links. Rootfs is a generated build input, not a
# checked-in binary blob.
mkdir -p "$ROOT"
bsdtar --numeric-owner -cpf "$ROOT/archlinuxarm-aarch64.tar" -C "$WORK" .
sha256sum "$ROOT/archlinuxarm-aarch64.tar" | tee "$ROOT/archlinuxarm-aarch64.tar.sha256"
