# vicliu624-lofibox-widget

This historical package name is retained for an in-place upgrade of deployed
devices. Its 0.3.5-2 payload is no longer a layer-shell widget: it installs
LoFiBox Zero as Labwc-managed `lofibox-wayland`, a compact 320 x 170
`xdg_toplevel` application, plus the `lofibox` launcher. It is not a
framebuffer application and it does not ship a compositor or media runtime
libraries.

The build is locked to a LoFiBox Git commit, the exact firmware Buildroot SDK,
and the matching host `wayland-scanner` plus Wayland protocol XML sources.
It builds only the standard Wayland target, installs its
executable/launcher/assets/icon/desktop entry, and derives all ELF SONAME
dependencies from the release-local runtime owner map.

At startup LoFiBox strictly requires `ffmpeg`, `ffprobe`, and either
`paplay` or `aplay`. `ffprobe` is an explicit dependency on the feed's
`ffprobe` package; the r1 image's existing `ffmpeg` and native audio commands
remain runtime prerequisites. A missing capability causes a direct error
instead of reduced-media fallback.

Build it as part of the immutable r7 candidate from a Linux/WSL builder with a
completed matching TDVP Buildroot output:

```sh
export TDVP_SDK_ROOT=/path/to/output/host
export TDVP_FEED_BASE_ROOT=/path/to/output/target
export TDVP_K230_WAYLAND_SDK_OVERLAY=/path/to/generated-wayland-overlay
export TDVP_LOFIBOX_SOURCE_DIR=/path/to/LoFiBox-Zero
./scripts/build-all.sh --platform tdvp-k230-r1 --release r7 --output dist
```

The source checkout must be clean and exactly at the `SOURCE_REVISION` in
`package.env`.  The release candidate is signed only on the protected offline
signer after feed verification passes.
