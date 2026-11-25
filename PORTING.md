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

## Confirmed blockers in the imported Android source

The following are source-level blockers, not merely missing package selections:

- `app/src/main/java/com/doro/terminal/shell/linux/LinuxContainerManager.kt`
  still extracts an Ubuntu 24.04 rootfs, verifies Ubuntu-specific asset hashes,
  invokes `dpkg`/APT, configures Ubuntu locale and paths, installs Debian
  `.deb` payloads, and validates XFCE commands. This manager must be replaced
  with an Arch-aware `pacman` initialization path before first boot can work.
- `app/src/main/AndroidManifest.xml` still declares
  `com.doro.terminal.shell.x11.X11ServerService`.
- `app/src/main/java/com/doro/terminal/shell/x11/` contains the current Lorie
  X11 service/runtime/surface implementation. These classes cannot serve as a
  Wayland output bridge by changing environment variables.
- `app/src/main/assets/rootfs/` is currently absent. The repository therefore
  does not yet contain an embedded Arch ARM64 base rootfs.
- Existing offline payloads and desktop assets include Ubuntu/Debian packages,
  XFCE theme assets and Ubuntu-specific Mesa bundle paths. They must not be
  installed into Arch; replace them with Arch-compatible packages/configuration.

## CI status

The ARM64 Android APK workflow is being repaired independently of the desktop
port. A successful Gradle APK build would prove only that the Android shell
compiles; it would not prove that the Arch rootfs, Wayland output, KWin or GPU
acceleration work. The release gate remains a real first-boot and rendering
test on an ARM64 Android device.
