# Arch KDE Mobile

Arch Linux ARM64 + KDE Plasma 6 for Android, based on the original
[xishanp/Linuxhub](https://github.com/xishanp/Linuxhub) **1.2.0** source tag.

> **Port status: in progress.** The Android runtime/display integration is being
> ported from the pinned 1.2.0 source. This repository is not yet a buildable APK.

## Non-negotiable architecture

- Arch Linux ARM64 userspace; no Ubuntu or Debian rootfs.
- KDE Plasma 6; no GNOME.
- Wayland desktop session; X11 is not the primary display server.
- KWin is the Wayland compositor.
- Mesa hardware acceleration is enabled only after a real GPU backend is detected.
- ARM64 runs natively through PRoot on ARM64 Android; no QEMU or CPU translation.
- Preserve the 1.2.0 Android app lifecycle, terminal, storage, audio and initialization
  code where compatible, replacing the distribution and display integration.

## Upstream baseline

- Repository: https://github.com/xishanp/Linuxhub
- Tag: [1.2.0](https://github.com/xishanp/Linuxhub/tree/1.2.0)
- Tag commit: `dc90ca29ec502ff91b31d2fa4c172f885b2d3d7c`

The tag's Android source still contains Ubuntu/XFCE/X11 assumptions. The port must
replace those at the source level; changing labels or README text alone is not a port.

## Desktop stack

```text
Android Surface / input bridge
          │
Wayland presentation backend
          │
KWin (Wayland compositor)
          │
Plasma Workspace / Qt Wayland
          │
Mesa EGL / GBM / Vulkan
          │
Adreno KGSL + Freedreno/Turnip (when supported)
```

KWin itself is the compositor. A separate second compositor must not be launched on
top of KWin. The Android-to-Wayland presentation backend is a required integration
component; a headless compositor alone does not make a desktop visible in the Android
Surface.

## Build

The Android project and its original runtime assets are being imported and adapted.
Do not treat this repository as an installable APK until the ARM64 RootFS, Android
display bridge, Gradle modules and CI build have all been restored and tested.

See [PORTING.md](PORTING.md) for the implementation checklist.
