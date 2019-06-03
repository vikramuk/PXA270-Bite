SUBDIRS = src

SPEC = $(PACKAGE_NAME).spec
TARBALL = $(PACKAGE_NAME)-$(VERSION).tar.gz
$(TARBALL):
	$(MAKE) dist

RPMBUILDOPTS = --define "_sourcedir $(abs_builddir)" \
               --define "_specdir $(abs_builddir)" \
               --define "_builddir $(abs_builddir)" \
               --define "_srcrpmdir $(abs_builddir)" \
               --define "_rpmdir $(abs_builddir)"

srpm: clean
	$(MAKE) $(TARBALL)
	$(MAKE) $(SPEC)
	rpmbuild $(RPMBUILDOPTS) --nodeps -bs $(SPEC)

rpm: clean
	$(MAKE) $(TARBALL)
	$(MAKE) $(SPEC)
	rpmbuild $(RPMBUILDOPTS) -ba $(SPEC)
