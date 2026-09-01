# vicliu624-lofibox-widget

LoFiBox Zero is delivered to the T-Display K230 only as a native Wayland
layer-shell widget IPK.  It opens a compact 320 x 170 surface in Labwc; it is
not a framebuffer application and it does not ship a compositor or media
runtime libraries.

The build is locked to a LoFiBox Git commit, the exact firmware Buildroot SDK,
and the matching host `wayland-scanner` plus Wayland protocol XML sources.
The `wlr-layer-shell` XML is versioned with LoFiBox itself.  It builds only the
widget target, installs its executable/assets/icon/desktop entry, and derives
all ELF SONAME dependencies from the release-local runtime owner map.

At startup the widget strictly requires `ffmpeg`, `ffprobe`, and either
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
