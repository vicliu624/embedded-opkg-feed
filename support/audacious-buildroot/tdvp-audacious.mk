################################################################################
# tdvp-audacious
################################################################################

TDVP_AUDACIOUS_VERSION = 4.6.1
TDVP_AUDACIOUS_SOURCE = audacious-$(TDVP_AUDACIOUS_VERSION).tar.bz2
TDVP_AUDACIOUS_SITE = https://distfiles.audacious-media-player.org
TDVP_AUDACIOUS_LICENSE = BSD-2-Clause
TDVP_AUDACIOUS_LICENSE_FILES = COPYING
TDVP_AUDACIOUS_DEPENDENCIES = libglib2 libgtk3
TDVP_AUDACIOUS_CONF_OPTS = \
	-Ddbus=false \
	-Dqt=false \
	-Dqt5=false \
	-Dgtk=true \
	-Dgtk2=false \
	-Dlibarchive=false \
	-Dvalgrind=false

$(eval $(meson-package))

################################################################################
# tdvp-audacious-plugins
################################################################################

TDVP_AUDACIOUS_PLUGINS_VERSION = 4.6.1
TDVP_AUDACIOUS_PLUGINS_SOURCE = audacious-plugins-$(TDVP_AUDACIOUS_PLUGINS_VERSION).tar.bz2
TDVP_AUDACIOUS_PLUGINS_SITE = https://distfiles.audacious-media-player.org
TDVP_AUDACIOUS_PLUGINS_LICENSE = BSD-2-Clause
TDVP_AUDACIOUS_PLUGINS_LICENSE_FILES = COPYING
TDVP_AUDACIOUS_PLUGINS_DEPENDENCIES = \
	tdvp-audacious alsa-lib pulseaudio ffmpeg libglib2 libgtk3 zlib

# This is a local music player rather than a second desktop environment or a
# streaming-service bundle. Keep the GTK3 interface, local playlist/file
# tools, FFmpeg input, ALSA and PulseAudio outputs; disable every plugin that
# would pull Qt, X11, PipeWire, JACK, network services, visualizers, or an
# additional decoder/runtime family into the release.
TDVP_AUDACIOUS_PLUGINS_CONF_OPTS = \
	-Dgtk=true \
	-Dgtk2=false \
	-Dqt=false \
	-Dqt5=false \
	-Dgtkui=true \
	-Dqtui=false \
	-Dskins=false \
	-Dasx=false \
	-Dasx3=false \
	-Dcue=false \
	-Dm3u=true \
	-Dpls=true \
	-Dxspf=false \
	-Dgio=true \
	-Dmms=false \
	-Dneon=false \
	-Daac=false \
	-Dadplug=false \
	-Damidiplug=false \
	-Dcdaudio=false \
	-Dcdaudio-cddb=false \
	-Dconsole=false \
	-Dffaudio=true \
	-Dflac=false \
	-Dmetronome=false \
	-Dmodplug=false \
	-Dmpg123=false \
	-Dopenmpt=false \
	-Dopus=false \
	-Dpsf=false \
	-Dsid=false \
	-Dsndfile=false \
	-Dtonegen=false \
	-Dvorbis=false \
	-Dvtx=false \
	-Dwavpack=false \
	-Dxsf=false \
	-Dalsa=true \
	-Dcoreaudio=false \
	-Dfilewriter=false \
	-Dfilewriter-flac=false \
	-Dfilewriter-mp3=false \
	-Dfilewriter-ogg=false \
	-Djack=false \
	-Doss=false \
	-Dpipewire=false \
	-Dpulse=true \
	-Dqtaudio=false \
	-Dsdlout=false \
	-Dsndio=false \
	-Dalbumart=true \
	-Dampache=false \
	-Daosd=false \
	-Ddelete-files=false \
	-Dfilebrowser=true \
	-Dhotkey=false \
	-Dlirc=false \
	-Dlyrics=false \
	-Dmac-now-playing=false \
	-Dmpris2=false \
	-Dnotify=false \
	-Dplayback-history=true \
	-Dplaylist-manager=true \
	-Dscrobbler2=false \
	-Dsearchtool=true \
	-Dsongchange=false \
	-Dsonginfo=true \
	-Dstatusicon=false \
	-Dstreamtuner=false \
	-Dbackground-music=false \
	-Dbitcrusher=false \
	-Dbs2b=false \
	-Dcompressor=false \
	-Dcrossfade=false \
	-Dcrystalizer=false \
	-Decho=false \
	-Dladspa=false \
	-Dmixer=false \
	-Dresample=false \
	-Dsilence-removal=false \
	-Dsoxr=false \
	-Dspeedpitch=false \
	-Dstereo=false \
	-Dvoice-removal=false \
	-Dblurscope=false \
	-Dgl-spectrum=false \
	-Dspectrum-analyzer=false \
	-Dvumeter=false

$(eval $(meson-package))
