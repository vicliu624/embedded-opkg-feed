# ffprobe

This package provides the FFmpeg 4.4.4 `ffprobe` frontend required by the
LoFiBox widget to inspect local media metadata, embedded artwork and lyrics.
The current TDVP r1 base image provides `ffmpeg`, PulseAudio and ALSA commands
but not `ffprobe`; that missing application tool is delivered through the
signed feed instead of changing the firmware for one desktop application.

The build hook verifies the FFmpeg version and archive checksum in the exact
TDVP Buildroot tree, temporarily enables only `BR2_PACKAGE_FFMPEG_FFPROBE`,
and restores the completed firmware configuration before returning. The IPK
installs only `/usr/bin/ffprobe`; it never replaces `/usr/bin/ffmpeg`.
