#
# Makefile to build debian package 


all: 
	@echo build: build debian package
	@echo clean: clean debian package
	@echo list: list debian package

list:
	@debc

test:
	@echo no tests

clean:
	@dh_clean
	@-rm debian/stamp-makefile-build


build:
	@dpkg-buildpackage -rfakeroot -us -uc

check:
	@ /bin/true

INSTALL=install -m 755
INSTALL_FILE=install -m 644

#	#echo $(MAKEFLAGS)
install:
	$(INSTALL) -d $(DESTDIR)/enki/bin
	$(INSTALL)    bin/updown-node.sh bin/nodestatus bin/updown-cluster.sh $(DESTDIR)/enki/bin
	$(INSTALL) -d $(DESTDIR)/etc/enki/scripts
	$(INSTALL)    $(wildcard scripts/*) $(DESTDIR)/etc/enki/scripts
	$(INSTALL) -d $(DESTDIR)/etc/enki/templates
	$(INSTALL_FILE)    $(wildcard xen-templates/*) $(DESTDIR)/etc/enki/templates
	$(INSTALL) -d $(DESTDIR)/etc/enki/xen-scripts
	$(INSTALL_FILE)    $(wildcard xen-scripts/*) $(DESTDIR)/etc/enki/xen-scripts
