################################################################################
# tdvp-audacious
################################################################################

TDVP_AUDACIOUS_VERSION = 4.6.1
TDVP_AUDACIOUS_SOURCE = audacious-$(TDVP_AUDACIOUS_VERSION).tar.bz2
TDVP_AUDACIOUS_SITE = https://distfiles.audacious-media-player.org
TDVP_AUDACIOUS_LICENSE = BSD-2-Clause
TDVP_AUDACIOUS_LICENSE_FILES = COPYING
TDVP_AUDACIOUS_DEPENDENCIES = libglib2 libgtk3
# audacious-plugins discovers the core only through audacious.pc.  Make the
# core's development artefacts available to the dependent package's temporary
# Buildroot staging sysroot; the feed transaction owns and deletes that
# staging copy after packaging.
TDVP_AUDACIOUS_INSTALL_STAGING = YES
TDVP_AUDACIOUS_CONF_OPTS = \
	-Ddbus=false \
	-Dqt=false \
	-Dqt5=false \
	-Dgtk=true \
	-Dgtk2=false \
	-Dlibarchive=false \
	-Dvalgrind=false

$(eval $(meson-package))
