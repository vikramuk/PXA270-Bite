SUBDIRS = src
EXTRA_DIST = el/e2fsck.conf

TARBALL = $(PACKAGE_NAME)-$(VERSION).tar.gz

if ENABLE_EL
SPEC = el/$(PACKAGE_NAME).spec

RPMBUILDOPTS = --define "_sourcedir $(abs_builddir)" \
               --define "_specdir $(abs_builddir)" \
               --define "_builddir $(abs_builddir)" \
               --define "_srcrpmdir $(abs_builddir)" \
               --define "_rpmdir $(abs_builddir)" \
               --define "dist .xel6"

srpm: clean dist
	rpmbuild $(RPMBUILDOPTS) --nodeps -bs $(SPEC)

rpm: clean dist
	rpmbuild $(RPMBUILDOPTS) -ba $(SPEC)
endif

if ENABLE_GENTOO
GENERIC_EBUILD = gentoo/$(PACKAGE_NAME).ebuild
TARGET_EBUILD = /usr/local/portage/sys-apps/$(PACKAGE_NAME)/$(PACKAGE_NAME)-$(VERSION).ebuild
PORTAGE_DISTFILES = /usr/portage/distfiles

install_ebuild: $(GENERIC_EBUILD) dist
	install $(TARBALL) $(PORTAGE_DISTFILES)/$(TARBALL)
	install $(GENERIC_EBUILD) $(TARGET_EBUILD)
	ebuild $(TARGET_EBUILD) digest --force
endif
