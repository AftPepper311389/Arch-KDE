# 1.2.0 → Arch KDE / Wayland port

## Verified source baseline

- Upstream: `xishanp/Linuxhub`
- Tag: `1.2.0`
- Commit: `dc90ca29ec502ff91b31d2fa4c172f885b2d3d7c`

The 1.2.0 tag is not already an Arch/KDE/Wayland implementation. Its Android
sources include Ubuntu 24.04 paths, apt/dpkg setup, XFCE session startup, and an
X11 runtime. Those components must be migrated rather than renamed.

## Required source changes

- [ ] Import the complete 1.2.0 Android project, Gradle modules, native libraries,
      licenses and runtime assets.
- [ ] Replace Ubuntu RootFS paths/configuration with an Arch ARM64 RootFS.
- [ ] Replace apt/dpkg package installation and Ubuntu-specific repair scripts
      with pacman/keyring handling.
- [ ] Preserve PRoot ARM64 execution, bind mounts, user creation, audio, terminal,
      Android permissions and storage integration.
- [ ] Replace XFCE launch/configuration, panel, wallpaper and desktop shortcuts
      with Plasma Workspace configuration.
- [ ] Replace X11-only app display plumbing with a Wayland presentation bridge.
- [ ] Start a D-Bus user session and KWin/Plasma Wayland session with a valid
      `XDG_RUNTIME_DIR` and Wayland socket.
- [ ] Keep XWayland only as an optional compatibility layer for legacy apps.
- [ ] Detect the Android GPU device and Mesa driver before enabling hardware
      acceleration; never label llvmpipe/lavapipe as GPU acceleration.
- [ ] Add startup diagnostics for compositor, EGL, GBM, Vulkan and socket failures.
- [ ] Build and test the APK on ARM64 CI; test installation, first boot, desktop
      rendering, touch, keyboard, audio, suspend/resume and clean shutdown.

## Compositor / display correctness

KWin is the compositor for the Plasma session. Do not start Weston or another
compositor as a competing layer. The port also needs a working Wayland output
backend that presents KWin frames into the Android app's Surface. Without that
backend, a running KWin process can still result in a black screen.

The original Android X11 Surface/service cannot simply be relabelled as Wayland.
Its rendering, buffer transport, input and lifecycle interfaces must be replaced
or adapted to a Wayland-compatible implementation.

## GPU policy

Preferred Qualcomm path, when the device exposes the required interfaces:

```text
KWin → EGL/GBM → Mesa Freedreno → KGSL → Adreno
Vulkan applications → Mesa Turnip → KGSL → Adreno
```

The runtime must check the actual device nodes, Mesa DRI driver, EGL renderer and
Vulkan physical device. Software renderers are fallback-only and must be reported
honestly. GPU support varies by device/kernel and cannot be guaranteed by package
installation alone.

## Arch package bootstrap

`scripts/arch-kde-wayland-bootstrap.sh` installs the userspace packages into an
already-created Arch Linux ARM64 RootFS. It does not download or embed the RootFS
and is not a substitute for the Android display bridge.
