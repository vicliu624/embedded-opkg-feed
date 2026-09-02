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
